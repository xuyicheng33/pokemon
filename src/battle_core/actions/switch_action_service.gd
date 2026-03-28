extends RefCounted
class_name SwitchActionService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ActionResultScript := preload("res://src/battle_core/contracts/action_result.gd")

var leave_service
var action_cast_service
var action_log_service
var field_service

func resolve_missing_dependency() -> String:
    if leave_service == null:
        return "leave_service"
    if action_cast_service == null:
        return "action_cast_service"
    if action_log_service == null:
        return "action_log_service"
    if field_service == null:
        return "field_service"
    return ""

func execute_switch_action(queued_action, battle_state, content_index):
    var result = ActionResultScript.new()
    var command = queued_action.command
    var side_state = battle_state.get_side(command.side_id)
    if side_state == null or not side_state.has_bench_unit(command.target_unit_id):
        result.result_type = "invalid_battle"
        result.invalid_battle_code = ErrorCodesScript.INVALID_SWITCH_TARGET_NOT_BENCH
        return result
    var actor = battle_state.get_unit(command.actor_id)
    var target_unit = battle_state.get_unit(command.target_unit_id)
    action_log_service.log_switch_state(queued_action, battle_state, actor, target_unit)
    var on_switch_invalid_code = action_cast_service.execute_lifecycle_trigger_batch("on_switch", battle_state, content_index, [actor.unit_instance_id])
    if on_switch_invalid_code != null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = on_switch_invalid_code
        return result
    var on_exit_invalid_code = action_cast_service.execute_lifecycle_trigger_batch("on_exit", battle_state, content_index, [actor.unit_instance_id])
    if on_exit_invalid_code != null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = on_exit_invalid_code
        return result
    side_state.bench_order.append(actor.unit_instance_id)
    leave_service.leave_unit(battle_state, actor, "manual_switch", content_index)
    var field_break_invalid_code = field_service.break_field_if_creator_inactive(
        battle_state,
        content_index,
        battle_state.chain_context
    )
    if field_break_invalid_code != null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = field_break_invalid_code
        return result
    var bench_index: int = side_state.bench_order.find(command.target_unit_id)
    if bench_index >= 0:
        side_state.bench_order.remove_at(bench_index)
    side_state.set_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY, command.target_unit_id)
    target_unit.leave_state = LeaveStatesScript.ACTIVE
    target_unit.leave_reason = null
    target_unit.has_acted = true
    target_unit.action_window_passed = true
    action_log_service.log_state_enter(battle_state, target_unit)
    var on_enter_invalid_code = action_cast_service.execute_lifecycle_trigger_batch("on_enter", battle_state, content_index, [target_unit.unit_instance_id])
    if on_enter_invalid_code != null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = on_enter_invalid_code
        return result
    result.result_type = "resolved"
    return result
