extends RefCounted
class_name LeaveService

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger
var log_event_builder
var lifecycle_retention_policy
var last_invalid_battle_code: Variant = null

func resolve_missing_dependency() -> String:
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if lifecycle_retention_policy == null:
        return "lifecycle_retention_policy"
    return ""

func leave_unit(battle_state, unit_state, reason: String, content_index) -> void:
    last_invalid_battle_code = null
    var side_state = battle_state.get_side_for_unit(unit_state.unit_instance_id)
    if side_state == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return
    if lifecycle_retention_policy == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_COMPOSITION
        return
    for slot_id in side_state.active_slots.keys():
        if side_state.active_slots[slot_id] == unit_state.unit_instance_id:
            side_state.clear_active_unit(slot_id)
    var kept_effects: Array = []
    var removed_effects: Array = []
    var kept_rule_mods: Array = []
    for effect_instance in unit_state.effect_instances:
        if lifecycle_retention_policy.should_keep_effect_instance(effect_instance, reason):
            kept_effects.append(effect_instance)
        else:
            removed_effects.append(effect_instance)
    for rule_mod_instance in unit_state.rule_mod_instances:
        if lifecycle_retention_policy.should_keep_rule_mod_instance(rule_mod_instance, reason):
            kept_rule_mods.append(rule_mod_instance)
    unit_state.effect_instances = kept_effects
    unit_state.rule_mod_instances = kept_rule_mods
    unit_state.stat_stages = {
        "attack": 0,
        "defense": 0,
        "sp_attack": 0,
        "sp_defense": 0,
        "speed": 0,
    }
    unit_state.has_acted = false
    unit_state.action_window_passed = false
    unit_state.leave_reason = reason
    if reason == "faint":
        unit_state.current_hp = 0
    unit_state.leave_state = LeaveStatesScript.LEFT
    var state_exit_event = log_event_builder.build_event(
        EventTypesScript.STATE_EXIT,
        battle_state,
        {
            "source_instance_id": unit_state.unit_instance_id,
            "target_instance_id": unit_state.unit_instance_id,
            "leave_reason": reason,
            "trigger_name": "on_exit",
            "payload_summary": "%s left battle" % unit_state.public_id,
        }
    )
    battle_logger.append_event(state_exit_event)
    var state_exit_event_id: String = log_event_builder.resolve_event_id(state_exit_event)
    for effect_instance in removed_effects:
        var effect_definition = content_index.effects.get(effect_instance.def_id) if content_index != null else null
        if effect_definition == null:
            last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
            return
        var log_event = log_event_builder.build_effect_event(
            EventTypesScript.EFFECT_REMOVE_EFFECT,
            battle_state,
            state_exit_event_id,
            {
                "source_instance_id": effect_instance.source_instance_id,
                "target_instance_id": unit_state.unit_instance_id,
                "priority": effect_definition.priority,
                "trigger_name": "on_exit",
                "payload_summary": "effect removed on exit: %s" % effect_definition.id,
            }
        )
        battle_logger.append_event(log_event)
