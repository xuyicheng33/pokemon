extends RefCounted
class_name FieldApplyService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
var field_service
var domain_clash_orchestrator
var field_apply_log_service
var field_apply_effect_runner

func resolve_missing_dependency() -> String:
	if field_service == null:
		return "field_service"
	if field_service.has_method("resolve_missing_dependency"):
		var field_missing := str(field_service.resolve_missing_dependency())
		if not field_missing.is_empty():
			return "field_service.%s" % field_missing
	if domain_clash_orchestrator == null:
		return "domain_clash_orchestrator"
	var clash_missing := str(domain_clash_orchestrator.resolve_missing_dependency())
	if not clash_missing.is_empty():
		return "domain_clash_orchestrator.%s" % clash_missing
	if field_apply_log_service == null:
		return "field_apply_log_service"
	var log_missing := str(field_apply_log_service.resolve_missing_dependency())
	if not log_missing.is_empty():
		return "field_apply_log_service.%s" % log_missing
	if field_apply_effect_runner == null:
		return "field_apply_effect_runner"
	var effect_missing := str(field_apply_effect_runner.resolve_missing_dependency())
	if not effect_missing.is_empty():
		return "field_apply_effect_runner.%s" % effect_missing
	return ""

func apply_field(effect_definition, payload, effect_event, battle_state, content_index) -> Variant:
	if effect_definition == null or payload == null or effect_event == null:
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	var challenger_field_definition = content_index.fields.get(payload.field_definition_id)
	var before_field = battle_state.field_state
	var resolves_replacing_field_lifecycle := before_field != null and _is_replacing_current_field_from_its_lifecycle(effect_event, before_field)
	if before_field != null and not resolves_replacing_field_lifecycle:
		var conflict_result: Dictionary = domain_clash_orchestrator.resolve_field_conflict(
			before_field,
			challenger_field_definition,
			effect_event,
			battle_state,
			content_index
		)
		if domain_clash_orchestrator.last_invalid_battle_code != null:
			return domain_clash_orchestrator.last_invalid_battle_code
		if bool(conflict_result.get("blocked", false)):
			field_apply_log_service.log_field_blocked_by_active_domain(before_field, payload, effect_event, battle_state)
			return null
		var clash_result: Dictionary = conflict_result.get("clash_result", {})
		if not clash_result.is_empty():
			field_apply_log_service.log_field_clash(clash_result, before_field, payload, effect_event, battle_state)
			if not bool(clash_result.get("challenger_won", false)):
				var release_invalid_code = field_apply_effect_runner.execute_pending_success_effects(before_field, battle_state, content_index)
				if release_invalid_code != null:
					return release_invalid_code
				return null
		if bool(conflict_result.get("should_break_before_apply", false)):
			var break_invalid_code = field_service.break_active_field(
				battle_state,
				content_index,
				"field_break",
				effect_event.chain_context
			)
			if break_invalid_code != null:
				return break_invalid_code
	var field_state = field_apply_effect_runner.create_field_state(effect_definition, payload, effect_event)
	if field_state == null:
		return field_apply_effect_runner.last_invalid_battle_code if field_apply_effect_runner.last_invalid_battle_code != null else ErrorCodesScript.INVALID_STATE_CORRUPTION
	battle_state.field_state = field_state
	field_apply_log_service.log_apply_field(before_field, field_state, effect_event, battle_state)
	var field_apply_invalid_code = field_apply_effect_runner.execute_field_effects(
		"field_apply",
		field_state,
		battle_state,
		content_index,
		effect_event.chain_context
	)
	if field_apply_invalid_code != null:
		return field_apply_invalid_code
	if _should_defer_success_effects(challenger_field_definition, payload, effect_event):
		field_apply_effect_runner.defer_success_effects(field_state, payload.on_success_effect_ids, effect_event)
		return null
	return field_apply_effect_runner.execute_success_effects(payload.on_success_effect_ids, effect_event, battle_state, content_index)

func _should_defer_success_effects(field_definition, payload, effect_event) -> bool:
	if field_definition == null or payload == null or effect_event == null or effect_event.chain_context == null:
		return false
	if payload.on_success_effect_ids.is_empty():
		return false
	if String(field_definition.field_kind) != ContentSchemaScript.FIELD_KIND_DOMAIN:
		return false
	return bool(effect_event.chain_context.defer_field_apply_success)

func _is_replacing_current_field_from_its_lifecycle(effect_event, current_field_state) -> bool:
	if effect_event == null or current_field_state == null:
		return false
	var trigger_name := String(effect_event.trigger_name)
	if trigger_name != "field_break" and trigger_name != "field_expire":
		return false
	return String(effect_event.source_instance_id) == String(current_field_state.instance_id)
