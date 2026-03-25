extends RefCounted
class_name FaintResolver

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var leave_service
var replacement_service
var battle_logger
var log_event_builder

func resolve_faint_window(battle_state) -> void:
    var fainted_units: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null:
            continue
        if active_unit.current_hp <= 0 and active_unit.leave_state == LeaveStatesScript.ACTIVE:
            active_unit.leave_state = LeaveStatesScript.FAINTED_PENDING_LEAVE
            active_unit.leave_reason = "faint"
            fainted_units.append(active_unit)
    for fainted_unit in fainted_units:
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.STATE_FAINT,
            battle_state,
            {
                "source_instance_id": fainted_unit.unit_instance_id,
                "target_instance_id": fainted_unit.unit_instance_id,
                "leave_reason": "faint",
                "payload_summary": "%s fainted" % fainted_unit.public_id,
            }
        ))
    for fainted_unit in fainted_units:
        leave_service.leave_unit(battle_state, fainted_unit, "faint")
    for side_state in battle_state.sides:
        if side_state.get_active_unit() == null:
            replacement_service.resolve_replacement(battle_state, side_state)
