extends RefCounted
class_name PayloadStatModRuntimeService

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
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ValueChangeFactoryScript := preload("res://src/battle_core/contracts/value_change_factory.gd")

var battle_logger: BattleLogger
var log_event_builder: LogEventBuilder
var target_helper: PayloadUnitTargetHelper
var effect_event_helper: PayloadEffectEventHelper

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func apply_stat_mod_payload(payload, effect_definition, effect_event: EffectEvent, battle_state: BattleState) -> void:
	var target_unit = target_helper.resolve_target_unit(effect_definition.scope, effect_event, battle_state)
	if not target_helper.is_effect_target_valid(target_unit, effect_definition.scope, effect_event):
		return
	var resolved_stage_delta: int = int(payload.stage_delta)
	if _should_consume_field_reversible_stat_mod(effect_event, battle_state):
		if target_unit.leave_state != LeaveStatesScript.ACTIVE:
			battle_state.field_state.clear_reversible_stat_mod(
				target_unit.unit_instance_id,
				String(payload.stat_name)
			)
			return
		resolved_stage_delta = battle_state.field_state.consume_reversible_stat_mod(
			target_unit.unit_instance_id,
			String(payload.stat_name),
			resolved_stage_delta
		)
		if resolved_stage_delta == 0:
			return
	var target_stage_bucket: Dictionary = target_unit.persistent_stat_stages if String(payload.retention_mode) == "persist_on_switch" else target_unit.stat_stages
	var before_value: int = int(target_stage_bucket.get(payload.stat_name, 0))
	var after_value: int = clamp(before_value + resolved_stage_delta, -2, 2)
	if before_value == after_value:
		if _should_record_field_reversible_stat_mod(effect_event, battle_state):
			battle_state.field_state.ensure_reversible_stat_mod_slot(
				target_unit.unit_instance_id,
				String(payload.stat_name)
			)
		return
	target_stage_bucket[payload.stat_name] = after_value
	if _should_record_field_reversible_stat_mod(effect_event, battle_state):
		battle_state.field_state.record_reversible_stat_mod(
			target_unit.unit_instance_id,
			String(payload.stat_name),
			after_value - before_value
		)
	var value_change = _build_value_change(target_unit.unit_instance_id, payload.stat_name, before_value, after_value)
	battle_logger.append_event(log_event_builder.build_effect_event(
		EventTypesScript.EFFECT_STAT_MOD,
		battle_state,
		String(effect_event.event_id),
		{
			"source_instance_id": effect_event.source_instance_id,
			"target_instance_id": target_unit.unit_instance_id,
			"priority": effect_event.priority,
			"trigger_name": effect_event.trigger_name,
			"effect_roll": effect_event_helper.resolve_effect_roll(effect_event),
			"value_changes": [value_change],
			"payload_summary": "%s %s %+d" % [target_unit.public_id, payload.stat_name, value_change.delta],
		}
	))

func _should_record_field_reversible_stat_mod(effect_event: EffectEvent, battle_state: BattleState) -> bool:
	return battle_state != null \
		and battle_state.field_state != null \
		and effect_event != null \
		and effect_event.trigger_name == "field_apply" \
		and effect_event.source_instance_id == battle_state.field_state.instance_id

func _should_consume_field_reversible_stat_mod(effect_event: EffectEvent, battle_state: BattleState) -> bool:
	return battle_state != null \
		and battle_state.field_state != null \
		and effect_event != null \
		and (effect_event.trigger_name == "field_break" or effect_event.trigger_name == "field_expire") \
		and effect_event.source_instance_id == battle_state.field_state.instance_id

func _build_value_change(entity_id: String, resource_name: String, before_value: int, after_value: int) -> Variant:
	return ValueChangeFactoryScript.create(entity_id, resource_name, before_value, after_value)
