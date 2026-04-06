extends RefCounted
class_name SwitchActionService

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ActionResultScript := preload("res://src/battle_core/contracts/action_result.gd")

var action_cast_service
var action_log_service
var replacement_service

func resolve_missing_dependency() -> String:
    if action_cast_service == null:
        return "action_cast_service"
    if action_cast_service.has_method("resolve_missing_dependency"):
        var cast_missing := str(action_cast_service.resolve_missing_dependency())
        if not cast_missing.is_empty():
            return "action_cast_service.%s" % cast_missing
    if action_log_service == null:
        return "action_log_service"
    if action_log_service.has_method("resolve_missing_dependency"):
        var log_missing := str(action_log_service.resolve_missing_dependency())
        if not log_missing.is_empty():
            return "action_log_service.%s" % log_missing
    if replacement_service == null:
        return "replacement_service"
    if replacement_service.has_method("resolve_missing_dependency"):
        var replacement_missing := str(replacement_service.resolve_missing_dependency())
        if not replacement_missing.is_empty():
            return "replacement_service.%s" % replacement_missing
    return ""

func execute_switch_action(queued_action, battle_state, content_index) -> Variant:
    var result = ActionResultScript.new()
    var command = queued_action.command
    var side_state = battle_state.get_side(command.side_id)
    if side_state == null or not side_state.has_bench_unit(command.target_unit_id):
        result.result_type = "invalid_battle"
        result.invalid_battle_code = ErrorCodesScript.INVALID_SWITCH_TARGET_NOT_BENCH
        return result
    var actor = battle_state.get_unit(command.actor_id)
    var target_unit = battle_state.get_unit(command.target_unit_id)
    if actor == null or target_unit == null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return result
    action_log_service.log_switch_state(queued_action, battle_state, actor, target_unit)
    var replace_result: Dictionary = replacement_service.execute_replacement_lifecycle(
        battle_state,
        content_index,
        actor.unit_instance_id,
        command.target_unit_id,
        "manual_switch",
        action_cast_service.trigger_batch_executor()
    )
    var invalid_code = replace_result.get("invalid_code", null)
    if invalid_code != null:
        result.result_type = "invalid_battle"
        result.invalid_battle_code = invalid_code
        return result
    result.result_type = "resolved"
    return result
