extends RefCounted
class_name ActionExecutor

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ActionResultScript := preload("res://src/battle_core/contracts/action_result.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var action_chain_context_builder
var action_start_phase_service
var action_skill_effect_service
var action_execution_resolution_service
var switch_action_service
var action_log_service
var action_domain_guard

func resolve_missing_dependency() -> String:
    if action_chain_context_builder == null:
        return "action_chain_context_builder"
    if action_start_phase_service == null:
        return "action_start_phase_service"
    var start_missing := str(action_start_phase_service.resolve_missing_dependency())
    if not start_missing.is_empty():
        return "action_start_phase_service.%s" % start_missing
    if action_skill_effect_service == null:
        return "action_skill_effect_service"
    var effect_missing := str(action_skill_effect_service.resolve_missing_dependency())
    if not effect_missing.is_empty():
        return "action_skill_effect_service.%s" % effect_missing
    if action_execution_resolution_service == null:
        return "action_execution_resolution_service"
    var resolution_missing := str(action_execution_resolution_service.resolve_missing_dependency())
    if not resolution_missing.is_empty():
        return "action_execution_resolution_service.%s" % resolution_missing
    if switch_action_service == null:
        return "switch_action_service"
    var switch_missing := str(switch_action_service.resolve_missing_dependency())
    if not switch_missing.is_empty():
        return "switch_action_service.%s" % switch_missing
    if action_log_service == null:
        return "action_log_service"
    var log_missing := str(action_log_service.resolve_missing_dependency())
    if not log_missing.is_empty():
        return "action_log_service.%s" % log_missing
    if action_domain_guard == null:
        return "action_domain_guard"
    var domain_missing := str(action_domain_guard.resolve_missing_dependency())
    if not domain_missing.is_empty():
        return "action_domain_guard.%s" % domain_missing
    return ""

func execute_action(queued_action, battle_state, content_index) -> Variant:
    var result = ActionResultScript.new()
    result.action_id = queued_action.action_id
    var command = queued_action.command
    var actor = battle_state.get_unit(command.actor_id)
    var skill_definition = _resolve_skill_definition(command, content_index)
    battle_state.chain_context = action_chain_context_builder.build_chain_context(queued_action, battle_state, skill_definition)
    if _uses_skill_definition(command.command_type):
        if skill_definition == null:
            result.invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
            return result
    if not _can_start_and_stay_legal(queued_action, command, actor, battle_state, content_index):
        _log_cancelled_pre_start(queued_action, battle_state, command, result)
        return result
    var start_phase: Dictionary = action_start_phase_service.apply_action_start_phase(
        queued_action,
        battle_state,
        actor,
        command,
        skill_definition
    )
    result.consumed_mp = int(start_phase["consumed_mp"])
    if start_phase["result_type"] != null:
        result.result_type = str(start_phase["result_type"])
        return result
    action_skill_effect_service.dispatch_trigger("on_cast", skill_definition, queued_action, actor, battle_state, content_index, result)
    if result.invalid_battle_code != null:
        return result
    if command.command_type == CommandTypesScript.SWITCH:
        var switch_result = switch_action_service.execute_switch_action(queued_action, battle_state, content_index)
        switch_result.action_id = queued_action.action_id
        return switch_result
    action_execution_resolution_service.resolve_started_action(
        queued_action,
        actor,
        command,
        skill_definition,
        battle_state,
        content_index,
        result
    )
    return result

func _resolve_skill_definition(command, content_index) -> Variant:
    if not _uses_skill_definition(command.command_type):
        return null
    return content_index.skills.get(command.skill_id, null)

func _uses_skill_definition(command_type: String) -> bool:
    return command_type == CommandTypesScript.SKILL or command_type == CommandTypesScript.ULTIMATE

func _can_start_and_stay_legal(queued_action, command, actor, battle_state, content_index) -> bool:
    if not _can_start_action(actor, command, battle_state):
        return false
    return action_domain_guard.is_action_still_allowed(queued_action, command, actor, battle_state, content_index)

func _log_cancelled_pre_start(queued_action, battle_state, command, result) -> void:
    action_log_service.log_action_cancelled_pre_start(queued_action, battle_state, command)
    result.result_type = "cancelled_pre_start"

func _can_start_action(actor, command, battle_state) -> bool:
    if actor == null or actor.current_hp <= 0 or actor.leave_state != LeaveStatesScript.ACTIVE:
        return false
    var side_state = battle_state.get_side(command.side_id)
    return side_state != null and side_state.get_active_unit() != null and side_state.get_active_unit().unit_instance_id == actor.unit_instance_id
