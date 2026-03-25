extends RefCounted
class_name ReplacementService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var battle_logger
var log_event_builder

func resolve_replacement(battle_state, side_state):
    for bench_unit_id in side_state.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit == null or bench_unit.current_hp <= 0:
            continue
        side_state.set_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY, bench_unit_id)
        var bench_index: int = side_state.bench_order.find(bench_unit_id)
        if bench_index >= 0:
            side_state.bench_order.remove_at(bench_index)
        bench_unit.leave_state = LeaveStatesScript.ACTIVE
        bench_unit.leave_reason = null
        bench_unit.has_acted = false
        bench_unit.action_window_passed = false
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.STATE_REPLACE,
            battle_state,
            {
                "source_instance_id": bench_unit.unit_instance_id,
                "target_instance_id": bench_unit.unit_instance_id,
                "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
                "trigger_name": "replace",
                "payload_summary": "%s replaced into battle" % bench_unit.public_id,
            }
        ))
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.STATE_ENTER,
            battle_state,
            {
                "source_instance_id": bench_unit.unit_instance_id,
                "target_instance_id": bench_unit.unit_instance_id,
                "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
                "trigger_name": "on_enter",
                "payload_summary": "%s entered battle" % bench_unit.public_id,
            }
        ))
        return bench_unit
    return null
