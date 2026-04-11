extends RefCounted
class_name ReplayRunnerInputHelper

const BattleInputContractHelperScript := preload("res://src/battle_core/contracts/battle_input_contract_helper.gd")

func validate_replay_input(replay_input) -> String:
	return BattleInputContractHelperScript.validate_replay_input_error(
		replay_input,
		"ReplayRunner.run_replay_with_context"
	)

func group_commands_by_turn(command_stream: Array) -> Dictionary:
	var commands_by_turn: Dictionary = {}
	for command in command_stream:
		if command == null:
			continue
		var turn_index: int = int(command.turn_index)
		if not commands_by_turn.has(turn_index):
			commands_by_turn[turn_index] = []
		commands_by_turn[turn_index].append(command)
	return commands_by_turn
