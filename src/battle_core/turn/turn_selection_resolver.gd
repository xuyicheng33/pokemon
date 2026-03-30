extends RefCounted
class_name TurnSelectionResolver

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const SelectionStateScript := preload("res://src/battle_core/contracts/selection_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var legal_action_service
var command_builder
var command_validator

func resolve_missing_dependency() -> String:
    if legal_action_service == null:
        return "legal_action_service"
    if command_builder == null:
        return "command_builder"
    if command_validator == null:
        return "command_validator"
    return ""

func reset_turn_state(battle_state) -> void:
    for side_state in battle_state.sides:
        side_state.selection_state = SelectionStateScript.new()
        for unit_state in side_state.team_units:
            unit_state.has_acted = false

func resolve_commands_for_turn(battle_state, content_index, commands: Array) -> Dictionary:
    var allowed_side_ids: Dictionary = {}
    for side_state in battle_state.sides:
        allowed_side_ids[side_state.side_id] = true
    var commands_by_side: Dictionary = {}
    for command in commands:
        if command == null or not allowed_side_ids.has(command.side_id):
            return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
        if commands_by_side.has(command.side_id):
            return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
        commands_by_side[command.side_id] = command
    var locked_commands: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null and _side_has_available_unit(side_state):
            return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
        var legal_action_set = legal_action_service.get_legal_actions(battle_state, side_state.side_id, content_index)
        var provided_command = commands_by_side.get(side_state.side_id, null)
        var resolved_command = null
        if provided_command != null and provided_command.command_type == CommandTypesScript.SURRENDER:
            resolved_command = provided_command
        elif not legal_action_set.forced_command_type.is_empty():
            if provided_command != null:
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
            var forced_actor = active_unit
            if forced_actor == null:
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
            resolved_command = command_builder.build_command({
                "turn_index": battle_state.turn_index,
                "command_type": CommandTypesScript.RESOURCE_FORCED_DEFAULT,
                "command_source": "resource_auto",
                "side_id": side_state.side_id,
                "actor_id": forced_actor.unit_instance_id,
            })
        elif provided_command == null:
            var timeout_actor = active_unit
            if timeout_actor == null:
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
            resolved_command = command_builder.build_command({
                "turn_index": battle_state.turn_index,
                "command_type": CommandTypesScript.WAIT,
                "command_source": "timeout_auto",
                "side_id": side_state.side_id,
                "actor_id": timeout_actor.unit_instance_id,
            })
        else:
            if not command_validator.validate_command(provided_command, battle_state, content_index):
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
            if not _is_command_in_legal_set(provided_command, legal_action_set, battle_state):
                return {"locked_commands": [], "invalid_code": ErrorCodesScript.INVALID_COMMAND_PAYLOAD}
            resolved_command = provided_command
        side_state.selection_state.selected_command = resolved_command
        side_state.selection_state.selection_locked = true
        side_state.selection_state.timed_out = resolved_command.command_source == "timeout_auto"
        locked_commands.append(resolved_command)
    return {"locked_commands": locked_commands, "invalid_code": null}

func _side_has_available_unit(side_state) -> bool:
    if side_state == null:
        return false
    for unit_state in side_state.team_units:
        if unit_state.current_hp > 0:
            return true
    return false

func clear_turn_end_state(battle_state) -> void:
    for side_state in battle_state.sides:
        side_state.selection_state = SelectionStateScript.new()
        for unit_state in side_state.team_units:
            unit_state.action_window_passed = false

func _is_command_in_legal_set(command, legal_action_set, battle_state) -> bool:
    match command.command_type:
        CommandTypesScript.SKILL:
            return legal_action_set.legal_skill_ids.has(command.skill_id)
        CommandTypesScript.ULTIMATE:
            return legal_action_set.legal_ultimate_ids.has(command.skill_id)
        CommandTypesScript.SWITCH:
            return legal_action_set.legal_switch_target_public_ids.has(_resolve_switch_target_public_id(command, battle_state))
        CommandTypesScript.WAIT:
            return legal_action_set.wait_allowed
        CommandTypesScript.SURRENDER:
            return true
        _:
            return false

func _resolve_switch_target_public_id(command, battle_state) -> String:
    if not command.target_public_id.is_empty():
        return command.target_public_id
    if command.target_unit_id.is_empty():
        return ""
    var target_unit = battle_state.get_unit(command.target_unit_id)
    if target_unit == null:
        return ""
    return target_unit.public_id
