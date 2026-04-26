extends RefCounted
class_name PayloadRuleModHandler

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "battle_logger",
		"source": "battle_logger",
		"nested": true,
	},
	{
		"field": "log_event_builder",
		"source": "log_event_builder",
		"nested": true,
	},
	{
		"field": "rule_mod_service",
		"source": "rule_mod_service",
		"nested": true,
	},
	{
		"field": "rule_mod_value_resolver",
		"source": "rule_mod_value_resolver",
		"nested": true,
	},
	{
		"field": "target_helper",
		"source": "payload_unit_target_helper",
		"nested": true,
	},
	{
		"field": "effect_event_helper",
		"source": "payload_effect_event_helper",
		"nested": true,
	},
]

const EventTypesScript := preload("res://src/shared/event_types.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var rule_mod_service: RuleModService
var rule_mod_value_resolver: RuleModValueResolver
var target_helper: PayloadUnitTargetHelper
var effect_event_helper: PayloadEffectEventHelper

var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func execute(payload, _effect_definition, effect_event: EffectEvent, battle_state: BattleState, _content_index: BattleContentIndex, _execute_trigger_batch: Callable = Callable()) -> void:
	last_invalid_battle_code = null
	if not payload is RuleModPayloadScript:
		return
	var owner_ref = _resolve_rule_mod_owner(payload, effect_event, battle_state)
	if owner_ref == null:
		return
	var resolved_value = rule_mod_value_resolver.resolve_value(payload, effect_event, battle_state)
	var resolver_error_state: Dictionary = rule_mod_value_resolver.error_state()
	if resolver_error_state.get("code", null) != null:
		last_invalid_battle_code = resolver_error_state.get("code", null)
		return
	var created_instance = rule_mod_service.create_instance(
		payload,
		owner_ref,
		battle_state,
		effect_event.source_instance_id,
		effect_event.source_kind_order,
		effect_event.source_order_speed_snapshot,
		resolved_value,
		String(effect_event.effect_definition_id)
	)
	if created_instance == null:
		var rule_mod_error_state: Dictionary = rule_mod_service.error_state() if rule_mod_service != null else {}
		last_invalid_battle_code = rule_mod_error_state.get("code", ErrorCodesScript.INVALID_RULE_MOD_DEFINITION)
		return
	if rule_mod_service.last_apply_skipped:
		return
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.EFFECT_RULE_MOD_APPLY,
		battle_state,
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": owner_ref["id"],
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"cause_event_id": effect_event.event_id,
			"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
			"payload_summary": "rule mod %s (%s)" % [created_instance.mod_kind, created_instance.instance_id],
		}
	))

func _resolve_rule_mod_owner(payload, effect_event: EffectEvent, battle_state: BattleState) -> Variant:
	match payload.scope:
		"self":
			var owner_unit = battle_state.get_unit(effect_event.owner_id)
			if owner_unit == null:
				last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
				return null
			if not target_helper.is_effect_target_valid(owner_unit, payload.scope, effect_event):
				return null
			return {"scope": "unit", "id": owner_unit.unit_instance_id}
		"target":
			if effect_event.chain_context == null or effect_event.chain_context.target_unit_id == null:
				last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
				return null
			var target_unit = battle_state.get_unit(str(effect_event.chain_context.target_unit_id))
			if target_unit == null:
				last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
				return null
			if not target_helper.is_effect_target_valid(target_unit, payload.scope, effect_event):
				return null
			return {"scope": "unit", "id": target_unit.unit_instance_id}
		"field":
			return {"scope": "field", "id": "field"}
		_:
			last_invalid_battle_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
			return null
