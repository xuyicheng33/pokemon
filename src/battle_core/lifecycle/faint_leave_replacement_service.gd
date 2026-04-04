extends RefCounted
class_name FaintLeaveReplacementService

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var leave_service
var replacement_service
var field_service

func resolve_missing_dependency() -> String:
    if leave_service == null:
        return "leave_service"
    if leave_service.has_method("resolve_missing_dependency"):
        var leave_missing := str(leave_service.resolve_missing_dependency())
        if not leave_missing.is_empty():
            return "leave_service.%s" % leave_missing
    if replacement_service == null:
        return "replacement_service"
    if replacement_service.has_method("resolve_missing_dependency"):
        var replacement_missing := str(replacement_service.resolve_missing_dependency())
        if not replacement_missing.is_empty():
            return "replacement_service.%s" % replacement_missing
    if field_service == null:
        return "field_service"
    if field_service.has_method("resolve_missing_dependency"):
        var field_missing := str(field_service.resolve_missing_dependency())
        if not field_missing.is_empty():
            return "field_service.%s" % field_missing
    return ""

func collect_pending_fainted_units(battle_state) -> Array:
    var fainted_units: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null:
            continue
        if active_unit.current_hp <= 0 and active_unit.leave_state == LeaveStatesScript.ACTIVE:
            active_unit.leave_state = LeaveStatesScript.FAINTED_PENDING_LEAVE
            active_unit.leave_reason = "faint"
            fainted_units.append(active_unit)
    return fainted_units

func resolve_fainted_units_leave(battle_state, content_index, fainted_units: Array, execute_trigger_batch: Callable) -> Variant:
    var fainted_unit_ids: Array = collect_unit_ids(fainted_units)
    var on_exit_invalid_code = execute_trigger_batch.call("on_exit", battle_state, content_index, fainted_unit_ids)
    if on_exit_invalid_code != null:
        return on_exit_invalid_code
    for fainted_unit in fainted_units:
        leave_service.leave_unit(battle_state, fainted_unit, "faint", content_index)
        if leave_service.invalid_battle_code() != null:
            return leave_service.invalid_battle_code()
    var field_break_invalid_code = field_service.break_field_if_creator_inactive(
        battle_state,
        content_index,
        battle_state.chain_context
    )
    if field_break_invalid_code != null:
        return field_break_invalid_code
    return null

func resolve_faint_replacements(battle_state) -> Dictionary:
    var entered_unit_ids: Array = []
    for side_state in battle_state.sides:
        if side_state.get_active_unit() != null:
            continue
        var replacement_result: Dictionary = replacement_service.resolve_replacement(battle_state, side_state, "faint")
        var replacement_invalid_code = replacement_result.get("invalid_code", null)
        if replacement_invalid_code != null:
            return {"entered_unit_ids": [], "invalid_code": replacement_invalid_code}
        var entered_unit = replacement_result.get("entered_unit", null)
        if entered_unit != null:
            entered_unit_ids.append(entered_unit.unit_instance_id)
    return {"entered_unit_ids": entered_unit_ids, "invalid_code": null}

func has_pending_faint_active(battle_state) -> bool:
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null:
            continue
        if active_unit.current_hp <= 0 and active_unit.leave_state == LeaveStatesScript.ACTIVE:
            return true
    return false

func collect_unit_ids(units: Array) -> Array:
    var unit_ids: Array = []
    for unit in units:
        unit_ids.append(unit.unit_instance_id)
    return unit_ids
