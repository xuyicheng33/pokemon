extends RefCounted
class_name FieldApplyService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")
const FieldApplyLogServiceScript := preload("res://src/battle_core/passives/field_apply_log_service.gd")
const FieldApplyEffectRunnerScript := preload("res://src/battle_core/passives/field_apply_effect_runner.gd")

const COMPOSE_DEPS := [
	{"field": "field_service", "source": "field_service", "nested": true},
	{"field": "domain_clash_orchestrator", "source": "domain_clash_orchestrator", "nested": true},
	{"field": "battle_logger", "source": "battle_logger"},
	{"field": "log_event_builder", "source": "log_event_builder"},
	{"field": "field_apply_context_resolver", "source": "field_apply_context_resolver"},
	{"field": "trigger_dispatcher", "source": "trigger_dispatcher"},
	{"field": "id_factory", "source": "id_factory"},
]

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var field_service: FieldService
var domain_clash_orchestrator: DomainClashOrchestrator
var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var field_apply_context_resolver: FieldApplyContextResolver
var trigger_dispatcher: TriggerDispatcher
var id_factory: IdFactory
var field_apply_log_service: FieldApplyLogService
var field_apply_effect_runner: FieldApplyEffectRunner

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)

func _compose_post_wire() -> void:
	field_apply_log_service = FieldApplyLogServiceScript.new()
	field_apply_log_service.battle_logger = battle_logger
	field_apply_log_service.log_event_builder = log_event_builder
	field_apply_log_service.context_resolver = field_apply_context_resolver
	field_apply_effect_runner = FieldApplyEffectRunnerScript.new()
	field_apply_effect_runner.field_service = field_service
	field_apply_effect_runner.trigger_dispatcher = trigger_dispatcher
	field_apply_effect_runner.id_factory = id_factory
	field_apply_effect_runner.context_resolver = field_apply_context_resolver


func apply_field(
	effect_definition,
	payload,
	effect_event: EffectEvent,
	battle_state: BattleState,
	content_index: BattleContentIndex,
	execute_trigger_batch: Callable = Callable()
) -> Variant:
	if effect_definition == null or payload == null or effect_event == null:
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
	var challenger_field_definition = content_index.fields.get(payload.field_definition_id)
	if challenger_field_definition == null:
		return ErrorCodesScript.INVALID_STATE_CORRUPTION
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
		var clash_invalid_code = domain_clash_orchestrator.invalid_battle_code()
		if clash_invalid_code != null:
			return clash_invalid_code
		if bool(conflict_result.get("blocked", false)):
			field_apply_log_service.log_field_blocked_by_active_domain(before_field, payload, effect_event, battle_state)
			return null
		var clash_result = conflict_result.get("clash_result", null)
		if clash_result != null:
			field_apply_log_service.log_field_clash(clash_result, before_field, payload, effect_event, battle_state)
			if not bool(clash_result.challenger_won):
				var release_invalid_code = field_apply_effect_runner.execute_pending_success_effects(
					before_field,
					battle_state,
					content_index,
					execute_trigger_batch
				)
				if release_invalid_code != null:
					return release_invalid_code
				return null
		if bool(conflict_result.get("should_break_before_apply", false)):
			var break_invalid_code = field_service.break_active_field(
				battle_state,
				content_index,
				"field_break",
				effect_event.chain_context,
				execute_trigger_batch
			)
			if break_invalid_code != null:
				return break_invalid_code
	var field_state = field_apply_effect_runner.create_field_state(effect_definition, payload, effect_event)
	if field_state == null:
		var field_invalid_code = field_apply_effect_runner.invalid_battle_code()
		return field_invalid_code if field_invalid_code != null else ErrorCodesScript.INVALID_STATE_CORRUPTION
	battle_state.field_state = field_state
	field_apply_log_service.log_apply_field(before_field, field_state, effect_event, battle_state)
	var field_apply_invalid_code = field_apply_effect_runner.execute_field_effects(
		"field_apply",
		field_state,
		battle_state,
		content_index,
		effect_event.chain_context,
		execute_trigger_batch
	)
	if field_apply_invalid_code != null:
		return field_apply_invalid_code
	if _should_defer_success_effects(challenger_field_definition, payload, effect_event):
		field_apply_effect_runner.defer_success_effects(field_state, payload.on_success_effect_ids, effect_event)
		return null
	return field_apply_effect_runner.execute_success_effects(
		payload.on_success_effect_ids,
		effect_event,
		battle_state,
		content_index,
		execute_trigger_batch
	)

func _should_defer_success_effects(field_definition, payload, effect_event: EffectEvent) -> bool:
	if field_definition == null or payload == null or effect_event == null or effect_event.chain_context == null:
		return false
	if payload.on_success_effect_ids.is_empty():
		return false
	if String(field_definition.field_kind) != ContentSchemaScript.FIELD_KIND_DOMAIN:
		return false
	return bool(effect_event.chain_context.defer_field_apply_success)

func _is_replacing_current_field_from_its_lifecycle(effect_event: EffectEvent, current_field_state) -> bool:
	if effect_event == null or current_field_state == null:
		return false
	var trigger_name := String(effect_event.trigger_name)
	if trigger_name != "field_break" and trigger_name != "field_expire":
		return false
	return String(effect_event.source_instance_id) == String(current_field_state.instance_id)
