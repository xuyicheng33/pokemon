extends RefCounted
class_name PayloadStatModRuntimeService

const EventTypesScript := preload("res://src/shared/event_types.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ValueChangeScript := preload("res://src/battle_core/contracts/value_change.gd")

var battle_logger
var log_event_builder
var target_helper

func resolve_missing_dependency() -> String:
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if target_helper == null:
        return "target_helper"
    return ""

func apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state) -> void:
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
    var before_value: int = int(target_unit.stat_stages.get(payload.stat_name, 0))
    var after_value: int = clamp(before_value + resolved_stage_delta, -2, 2)
    if before_value == after_value:
        if _should_record_field_reversible_stat_mod(effect_event, battle_state):
            battle_state.field_state.ensure_reversible_stat_mod_slot(
                target_unit.unit_instance_id,
                String(payload.stat_name)
            )
        return
    target_unit.stat_stages[payload.stat_name] = after_value
    if _should_record_field_reversible_stat_mod(effect_event, battle_state):
        battle_state.field_state.record_reversible_stat_mod(
            target_unit.unit_instance_id,
            String(payload.stat_name),
            after_value - before_value
        )
    var value_change = _build_value_change(target_unit.unit_instance_id, payload.stat_name, before_value, after_value)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_STAT_MOD,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "effect_roll": _resolve_effect_roll(effect_event),
            "value_changes": [value_change],
            "payload_summary": "%s %s %+d" % [target_unit.public_id, payload.stat_name, value_change.delta],
        }
    ))

func _should_record_field_reversible_stat_mod(effect_event, battle_state) -> bool:
    return battle_state != null \
        and battle_state.field_state != null \
        and effect_event != null \
        and effect_event.trigger_name == "field_apply" \
        and effect_event.source_instance_id == battle_state.field_state.instance_id

func _should_consume_field_reversible_stat_mod(effect_event, battle_state) -> bool:
    return battle_state != null \
        and battle_state.field_state != null \
        and effect_event != null \
        and (effect_event.trigger_name == "field_break" or effect_event.trigger_name == "field_expire") \
        and effect_event.source_instance_id == battle_state.field_state.instance_id

func _build_value_change(entity_id: String, resource_name: String, before_value: int, after_value: int):
    var value_change = ValueChangeScript.new()
    value_change.entity_id = entity_id
    value_change.resource_name = resource_name
    value_change.before_value = before_value
    value_change.after_value = after_value
    value_change.delta = after_value - before_value
    return value_change

func _resolve_effect_roll(effect_event) -> Variant:
    return null if effect_event == null else effect_event.sort_random_roll
