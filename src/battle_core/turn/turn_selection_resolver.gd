extends RefCounted
class_name TurnSelectionResolver

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "legal_action_service",
		"source": "legal_action_service",
		"nested": true,
	},
	{
		"field": "command_builder",
		"source": "command_builder",
		"nested": true,
	},
	{
		"field": "command_validator",
		"source": "command_validator",
		"nested": true,
	},
]

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const SelectionStateScript := preload("res://src/battle_core/contracts/selection_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var legal_action_service: LegalActionService
var command_builder: CommandBuilder
var command_validator: CommandValidator
var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func reset_turn_state(battle_state: BattleState) -> void:
	for side_state in battle_state.sides:
		side_state.selection_state = SelectionStateScript.new()
		for unit_state in side_state.team_units:
			unit_state.has_acted = false

func resolve_commands_for_turn(battle_state: BattleState, content_index: BattleContentIndex, commands: Array) -> Dictionary:
	ErrorStateHelperScript.clear(self)
	var allowed_side_ids: Dictionary = {}
	for side_state in battle_state.sides:
		allowed_side_ids[side_state.side_id] = true
	var commands_by_side: Dictionary = {}
	for command in commands:
		if command == null or not allowed_side_ids.has(command.side_id):
			return _invalid_result(ErrorCodesScript.INVALID_COMMAND_PAYLOAD)
		if commands_by_side.has(command.side_id):
			return _invalid_result(ErrorCodesScript.INVALID_COMMAND_PAYLOAD)
		commands_by_side[command.side_id] = command
	var locked_commands: Array = []
	var pending_selection_results: Array = []
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit == null and _side_has_available_unit(side_state):
			return _invalid_result(ErrorCodesScript.INVALID_STATE_CORRUPTION)
		var legal_action_set = legal_action_service.get_legal_actions(battle_state, side_state.side_id, content_index)
		if legal_action_set == null:
			var service_error_state: Dictionary = legal_action_service.error_state() if legal_action_service != null and legal_action_service.has_method("error_state") else {}
			return _fail_invalid_result(
				battle_state,
				String(service_error_state.get("code", ErrorCodesScript.INVALID_STATE_CORRUPTION)),
				String(service_error_state.get("message", "TurnSelectionResolver failed to build legal_action_set"))
			)
		var provided_command = commands_by_side.get(side_state.side_id, null)
		var resolved_command = null
		if provided_command != null and provided_command.command_type == CommandTypesScript.SURRENDER:
			resolved_command = provided_command
		elif not legal_action_set.forced_command_type.is_empty():
			if provided_command != null:
				return _invalid_result(ErrorCodesScript.INVALID_COMMAND_PAYLOAD)
			var forced_actor = active_unit
			if forced_actor == null:
				return _invalid_result(ErrorCodesScript.INVALID_STATE_CORRUPTION)
			resolved_command = command_builder.build_command({
				"turn_index": battle_state.turn_index,
				"command_type": CommandTypesScript.RESOURCE_FORCED_DEFAULT,
				"command_source": "resource_auto",
				"side_id": side_state.side_id,
				"actor_id": forced_actor.unit_instance_id,
			})
			if resolved_command == null:
				return _service_invalid_result(
					battle_state,
					command_builder,
					ErrorCodesScript.INVALID_STATE_CORRUPTION,
					"TurnSelectionResolver failed to build forced default command"
				)
		elif provided_command == null:
			var timeout_actor = active_unit
			if timeout_actor == null:
				return _invalid_result(ErrorCodesScript.INVALID_STATE_CORRUPTION)
			resolved_command = command_builder.build_command({
				"turn_index": battle_state.turn_index,
				"command_type": CommandTypesScript.WAIT,
				"command_source": "timeout_auto",
				"side_id": side_state.side_id,
				"actor_id": timeout_actor.unit_instance_id,
			})
			if resolved_command == null:
				return _service_invalid_result(
					battle_state,
					command_builder,
					ErrorCodesScript.INVALID_STATE_CORRUPTION,
					"TurnSelectionResolver failed to build timeout wait command"
				)
		else:
			if not command_validator.validate_command(provided_command, battle_state, content_index):
				return _invalid_result(ErrorCodesScript.INVALID_COMMAND_PAYLOAD)
			if not _is_command_in_legal_set(provided_command, legal_action_set, battle_state):
				return _invalid_result(ErrorCodesScript.INVALID_COMMAND_PAYLOAD)
			resolved_command = provided_command
		pending_selection_results.append({
			"side_state": side_state,
			"resolved_command": resolved_command,
			"timed_out": String(resolved_command.command_source) == "timeout_auto",
		})
		locked_commands.append(resolved_command)
	for pending_selection_result in pending_selection_results:
		var pending_side_state = pending_selection_result.get("side_state", null)
		if pending_side_state == null:
			continue
		pending_side_state.selection_state.selected_command = pending_selection_result.get("resolved_command", null)
		pending_side_state.selection_state.selection_locked = true
		pending_side_state.selection_state.timed_out = bool(pending_selection_result.get("timed_out", false))
	return _success_result(locked_commands)

func _fail_invalid_result(battle_state: BattleState, invalid_code: String, message: String) -> Dictionary:
	ErrorStateHelperScript.fail(self, invalid_code, message)
	_clear_selection_state(battle_state)
	if battle_state != null:
		battle_state.runtime_fault_code = invalid_code
		battle_state.runtime_fault_message = message
	return _invalid_result(invalid_code, message)

func _service_invalid_result(battle_state: BattleState, service, fallback_code: String, fallback_message: String) -> Dictionary:
	var service_error_state: Dictionary = service.error_state() if service != null and service.has_method("error_state") else {}
	var invalid_code := String(service_error_state.get("code", fallback_code))
	var invalid_message := String(service_error_state.get("message", fallback_message))
	if invalid_message.is_empty():
		invalid_message = fallback_message
	return _fail_invalid_result(battle_state, invalid_code, invalid_message)

func _success_result(locked_commands: Array) -> Dictionary:
	return {
		"locked_commands": locked_commands,
		"invalid_code": null,
		"invalid_message": "",
	}

func _invalid_result(invalid_code: String, invalid_message: String = "") -> Dictionary:
	return {
		"locked_commands": [],
		"invalid_code": invalid_code,
		"invalid_message": invalid_message,
	}

func _clear_selection_state(battle_state: BattleState) -> void:
	if battle_state == null:
		return
	for side_state in battle_state.sides:
		side_state.selection_state = SelectionStateScript.new()

func _side_has_available_unit(side_state) -> bool:
	if side_state == null:
		return false
	for unit_state in side_state.team_units:
		if unit_state.current_hp > 0:
			return true
	return false

func clear_turn_end_state(battle_state: BattleState) -> void:
	for side_state in battle_state.sides:
		side_state.selection_state = SelectionStateScript.new()
		for unit_state in side_state.team_units:
			unit_state.action_window_passed = false

func _is_command_in_legal_set(command: Command, legal_action_set, battle_state: BattleState) -> bool:
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

func _resolve_switch_target_public_id(command: Command, battle_state: BattleState) -> String:
	if not command.target_public_id.is_empty():
		return command.target_public_id
	if command.target_unit_id.is_empty():
		return ""
	var target_unit = battle_state.get_unit(command.target_unit_id)
	if target_unit == null:
		return ""
	return target_unit.public_id
