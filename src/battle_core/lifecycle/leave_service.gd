extends RefCounted
class_name LeaveService

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var battle_logger
var log_event_builder

func leave_unit(battle_state, unit_state, reason: String) -> void:
    var side_state = battle_state.get_side_for_unit(unit_state.unit_instance_id)
    assert(side_state != null, "LeaveService missing side for %s" % unit_state.unit_instance_id)
    for slot_id in side_state.active_slots.keys():
        if side_state.active_slots[slot_id] == unit_state.unit_instance_id:
            side_state.clear_active_unit(slot_id)
    var kept_effects: Array = []
    if reason != "faint":
        for effect_instance in unit_state.effect_instances:
            if effect_instance.persists_on_switch:
                kept_effects.append(effect_instance)
    unit_state.effect_instances = kept_effects
    unit_state.rule_mod_instances.clear()
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
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.STATE_EXIT,
        battle_state,
        {
            "source_instance_id": unit_state.unit_instance_id,
            "target_instance_id": unit_state.unit_instance_id,
            "leave_reason": reason,
            "payload_summary": "%s left battle" % unit_state.public_id,
        }
    ))
