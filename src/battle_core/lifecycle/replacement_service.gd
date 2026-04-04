extends RefCounted
class_name ReplacementService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var battle_logger
var log_event_builder
var replacement_selector
var leave_service
var field_service

func resolve_missing_dependency() -> String:
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if replacement_selector == null:
        return "replacement_selector"
    if leave_service == null:
        return "leave_service"
    if leave_service.has_method("resolve_missing_dependency"):
        var leave_missing := str(leave_service.resolve_missing_dependency())
        if not leave_missing.is_empty():
            return "leave_service.%s" % leave_missing
    if field_service == null:
        return "field_service"
    if field_service.has_method("resolve_missing_dependency"):
        var field_missing := str(field_service.resolve_missing_dependency())
        if not field_missing.is_empty():
            return "field_service.%s" % field_missing
    return ""

func resolve_replacement(battle_state, side_state, reason: String) -> Dictionary:
    var legal_bench_ids := _collect_legal_bench_ids(battle_state, side_state)
    if legal_bench_ids.is_empty():
        return {"entered_unit": null, "invalid_code": null}
    var selected_unit_id: String = _select_replacement_unit_id(battle_state, side_state, legal_bench_ids, reason)
    if selected_unit_id.is_empty():
        return {"entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}
    var entered_unit = _enter_replacement(
        battle_state,
        side_state,
        ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
        selected_unit_id
    )
    if entered_unit == null:
        return {"entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}
    return {"entered_unit": entered_unit, "invalid_code": null}

func execute_forced_replace(
    battle_state,
    content_index,
    target_unit_id: String,
    selector_reason: String = "forced_replace",
    execute_trigger_batch: Callable = Callable()
) -> Dictionary:
    var target_unit = battle_state.get_unit(target_unit_id)
    if target_unit == null or target_unit.current_hp <= 0 or target_unit.leave_state != LeaveStatesScript.ACTIVE:
        return {"replaced": false, "entered_unit": null, "invalid_code": null}
    var side_state = battle_state.get_side_for_unit(target_unit_id)
    if side_state == null:
        return {"replaced": false, "entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
    var active_slot_id: String = _find_active_slot_id(side_state, target_unit_id)
    if active_slot_id.is_empty():
        return {"replaced": false, "entered_unit": null, "invalid_code": null}
    var legal_bench_ids := _collect_legal_bench_ids(battle_state, side_state)
    if legal_bench_ids.is_empty():
        return {"replaced": false, "entered_unit": null, "invalid_code": null}
    var selected_unit_id: String = _select_replacement_unit_id(
        battle_state,
        side_state,
        legal_bench_ids,
        selector_reason
    )
    if selected_unit_id.is_empty():
        return {"replaced": false, "entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}
    var selected_unit = battle_state.get_unit(selected_unit_id)
    if selected_unit == null or selected_unit.current_hp <= 0 or not side_state.has_bench_unit(selected_unit_id):
        return {"replaced": false, "entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.STATE_SWITCH,
        battle_state,
        {
            "source_instance_id": target_unit.unit_instance_id,
            "target_instance_id": selected_unit.unit_instance_id,
            "target_slot": active_slot_id,
            "leave_reason": "forced_replace",
            "trigger_name": "on_switch",
            "payload_summary": "%s forced replaced to %s" % [target_unit.public_id, selected_unit.public_id],
        }
    ))
    var on_switch_invalid_code = _execute_lifecycle_trigger_batch(
        "on_switch",
        battle_state,
        content_index,
        [target_unit.unit_instance_id],
        execute_trigger_batch
    )
    if on_switch_invalid_code != null:
        return {"replaced": false, "entered_unit": null, "invalid_code": on_switch_invalid_code}
    var on_exit_invalid_code = _execute_lifecycle_trigger_batch(
        "on_exit",
        battle_state,
        content_index,
        [target_unit.unit_instance_id],
        execute_trigger_batch
    )
    if on_exit_invalid_code != null:
        return {"replaced": false, "entered_unit": null, "invalid_code": on_exit_invalid_code}
    side_state.bench_order.append(target_unit.unit_instance_id)
    leave_service.leave_unit(battle_state, target_unit, "forced_replace", content_index)
    if leave_service.invalid_battle_code() != null:
        return {"replaced": false, "entered_unit": null, "invalid_code": leave_service.invalid_battle_code()}
    var field_break_invalid_code = field_service.break_field_if_creator_inactive(
        battle_state,
        content_index,
        battle_state.chain_context,
        execute_trigger_batch
    )
    if field_break_invalid_code != null:
        return {"replaced": false, "entered_unit": null, "invalid_code": field_break_invalid_code}
    var entered_unit = _enter_replacement(battle_state, side_state, active_slot_id, selected_unit_id)
    if entered_unit == null:
        return {"replaced": false, "entered_unit": null, "invalid_code": ErrorCodesScript.INVALID_REPLACEMENT_SELECTION}
    var on_enter_invalid_code = _execute_lifecycle_trigger_batch(
        "on_enter",
        battle_state,
        content_index,
        [entered_unit.unit_instance_id],
        execute_trigger_batch
    )
    if on_enter_invalid_code != null:
        return {"replaced": false, "entered_unit": entered_unit, "invalid_code": on_enter_invalid_code}
    return {"replaced": true, "entered_unit": entered_unit, "invalid_code": null}
func _collect_legal_bench_ids(battle_state, side_state) -> PackedStringArray:
    var legal_bench_ids := PackedStringArray()
    for bench_unit_id in side_state.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit == null or bench_unit.current_hp <= 0:
            continue
        legal_bench_ids.append(bench_unit_id)
    return legal_bench_ids
func _find_active_slot_id(side_state, unit_instance_id: String) -> String:
    for slot_id in side_state.active_slots.keys():
        if str(side_state.active_slots[slot_id]) == unit_instance_id:
            return str(slot_id)
    return ""
func _select_replacement_unit_id(battle_state, side_state, legal_bench_ids: PackedStringArray, reason: String) -> String:
    if legal_bench_ids.size() == 1:
        return legal_bench_ids[0]
    if replacement_selector == null:
        return ""
    var selected = replacement_selector.select_replacement(
        battle_state,
        side_state.side_id,
        legal_bench_ids,
        reason,
        battle_state.chain_context
    )
    var selected_unit_id := str(selected) if selected != null else ""
    if selected_unit_id.is_empty() or not legal_bench_ids.has(selected_unit_id):
        return ""
    return selected_unit_id
func _enter_replacement(battle_state, side_state, slot_id: String, selected_unit_id: String):
    var bench_unit = battle_state.get_unit(selected_unit_id)
    if bench_unit == null or bench_unit.current_hp <= 0 or not side_state.has_bench_unit(selected_unit_id):
        return null
    side_state.set_active_unit(slot_id, selected_unit_id)
    var bench_index: int = side_state.bench_order.find(selected_unit_id)
    if bench_index >= 0:
        side_state.bench_order.remove_at(bench_index)
    bench_unit.leave_state = LeaveStatesScript.ACTIVE
    bench_unit.leave_reason = null
    bench_unit.reentered_turn_index = battle_state.turn_index
    bench_unit.has_acted = false
    bench_unit.action_window_passed = false
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.STATE_REPLACE,
        battle_state,
        {
            "source_instance_id": bench_unit.unit_instance_id,
            "target_instance_id": bench_unit.unit_instance_id,
            "target_slot": slot_id,
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
            "target_slot": slot_id,
            "trigger_name": "on_enter",
            "payload_summary": "%s entered battle" % bench_unit.public_id,
        }
    ))
    return bench_unit
func _execute_lifecycle_trigger_batch(
    trigger_name: String,
    battle_state,
    content_index,
    owner_unit_ids: Array,
    execute_trigger_batch: Callable = Callable()
):
    if not execute_trigger_batch.is_valid():
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    return execute_trigger_batch.call(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        battle_state.chain_context
    )
