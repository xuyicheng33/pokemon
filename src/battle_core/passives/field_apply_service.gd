extends RefCounted
class_name FieldApplyService

const FieldApplyContextResolverScript := preload("res://src/battle_core/passives/field_apply_context_resolver.gd")
const FieldApplyConflictServiceScript := preload("res://src/battle_core/passives/field_apply_conflict_service.gd")
const FieldApplyLogServiceScript := preload("res://src/battle_core/passives/field_apply_log_service.gd")
const FieldApplyEffectRunnerScript := preload("res://src/battle_core/passives/field_apply_effect_runner.gd")

var field_service
var trigger_dispatcher
var trigger_batch_runner
var id_factory
var battle_logger
var log_event_builder
var rng_service

var _context_resolver = FieldApplyContextResolverScript.new()
var _conflict_service = FieldApplyConflictServiceScript.new()
var _log_service = FieldApplyLogServiceScript.new()
var _effect_runner = FieldApplyEffectRunnerScript.new()

func resolve_missing_dependency() -> String:
	if field_service == null:
		return "field_service"
	if field_service.has_method("resolve_missing_dependency"):
		var field_missing := str(field_service.resolve_missing_dependency())
		if not field_missing.is_empty():
			return "field_service.%s" % field_missing
	if trigger_dispatcher == null:
		return "trigger_dispatcher"
	if trigger_batch_runner == null:
		return "trigger_batch_runner"
	if id_factory == null:
		return "id_factory"
	if battle_logger == null:
		return "battle_logger"
	if log_event_builder == null:
		return "log_event_builder"
	if rng_service == null:
		return "rng_service"
	_sync_runtime_services()
	var conflict_missing := _conflict_service.resolve_missing_dependency()
	if not conflict_missing.is_empty():
		return "conflict_service.%s" % conflict_missing
	var log_missing := _log_service.resolve_missing_dependency()
	if not log_missing.is_empty():
		return "log_service.%s" % log_missing
	var effect_missing := _effect_runner.resolve_missing_dependency()
	if not effect_missing.is_empty():
		return "effect_runner.%s" % effect_missing
	return ""

func apply_field(effect_definition, payload, effect_event, battle_state, content_index) -> Variant:
	assert(effect_definition != null, "FieldApplyService.apply_field requires effect_definition")
	assert(payload != null, "FieldApplyService.apply_field requires payload")
	assert(effect_event != null, "FieldApplyService.apply_field requires effect_event")
	_sync_runtime_services()
	var challenger_field_definition = content_index.fields.get(payload.field_definition_id)
	var before_field = battle_state.field_state
	if before_field != null:
		var incumbent_field_definition = field_service.get_field_definition_for_state(before_field, content_index)
		if _conflict_service.is_normal_field_blocked_by_domain(challenger_field_definition, incumbent_field_definition):
			_log_service.log_field_blocked_by_active_domain(before_field, payload, effect_event, battle_state)
			return null
		if _conflict_service.should_resolve_domain_clash(challenger_field_definition, incumbent_field_definition):
			var clash_result := _conflict_service.resolve_field_clash(before_field, effect_event, battle_state)
			if clash_result.has("invalid_code"):
				return clash_result["invalid_code"]
			_log_service.log_field_clash(clash_result, before_field, payload, effect_event, battle_state)
			if not bool(clash_result.get("challenger_won", false)):
				return null
		var break_invalid_code = field_service.break_active_field(
			battle_state,
			content_index,
			"field_break",
			effect_event.chain_context
		)
		if break_invalid_code != null:
			return break_invalid_code
	var field_state = _effect_runner.create_field_state(effect_definition, payload, effect_event)
	battle_state.field_state = field_state
	_log_service.log_apply_field(before_field, field_state, effect_event, battle_state)
	var field_apply_invalid_code = _effect_runner.execute_field_effects(
		"field_apply",
		field_state,
		battle_state,
		content_index,
		effect_event.chain_context
	)
	if field_apply_invalid_code != null:
		return field_apply_invalid_code
	return _effect_runner.execute_success_effects(payload.on_success_effect_ids, effect_event, battle_state, content_index)

func _sync_runtime_services() -> void:
	_conflict_service.rng_service = rng_service
	_conflict_service.context_resolver = _context_resolver

	_log_service.battle_logger = battle_logger
	_log_service.log_event_builder = log_event_builder
	_log_service.context_resolver = _context_resolver

	_effect_runner.field_service = field_service
	_effect_runner.trigger_dispatcher = trigger_dispatcher
	_effect_runner.trigger_batch_runner = trigger_batch_runner
	_effect_runner.id_factory = id_factory
	_effect_runner.context_resolver = _context_resolver
