extends RefCounted
class_name ReplacementService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger
var log_event_builder
var replacement_selector

func resolve_replacement(battle_state, side_state, reason: String) -> Dictionary:
    var legal_bench_ids := _collect_legal_bench_ids(battle_state, side_state)
    if legal_bench_ids.is_empty():
        return {"entered_unit": null, "invalid_code": null}

    var selected_unit_id: String = ""
    if legal_bench_ids.size() == 1:
        selected_unit_id = legal_bench_ids[0]
    else:
        if replacement_selector == null:
            return {"entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}
        var selected = replacement_selector.select_replacement(
            battle_state,
            side_state.side_id,
            legal_bench_ids,
            reason,
            battle_state.chain_context
        )
        selected_unit_id = str(selected) if selected != null else ""
        if selected_unit_id.is_empty() or not legal_bench_ids.has(selected_unit_id):
            return {"entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}

    var bench_unit = battle_state.get_unit(selected_unit_id)
    if bench_unit == null or bench_unit.current_hp <= 0 or not side_state.has_bench_unit(selected_unit_id):
        return {"entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}

    side_state.set_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY, selected_unit_id)
    var bench_index: int = side_state.bench_order.find(selected_unit_id)
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
    return {"entered_unit": bench_unit, "invalid_code": null}

func _collect_legal_bench_ids(battle_state, side_state) -> PackedStringArray:
    var legal_bench_ids := PackedStringArray()
    for bench_unit_id in side_state.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit == null or bench_unit.current_hp <= 0:
            continue
        legal_bench_ids.append(bench_unit_id)
    return legal_bench_ids
