extends RefCounted
class_name ReplayRunnerInputHelper

func validate_replay_input(replay_input) -> String:
	if replay_input == null:
		return "ReplayRunner.run_replay_with_context requires replay_input"
	if not _has_property(replay_input, "battle_setup"):
		return "ReplayRunner.run_replay_with_context requires battle_setup"
	var battle_setup = replay_input.get("battle_setup")
	if battle_setup == null:
		return "ReplayRunner.run_replay_with_context requires battle_setup"
	if not _has_property(battle_setup, "sides"):
		return "ReplayRunner.run_replay_with_context requires battle_setup.sides"
	var sides = battle_setup.get("sides")
	if typeof(sides) != TYPE_ARRAY or sides.is_empty():
		return "ReplayRunner.run_replay_with_context requires battle_setup.sides to be a non-empty Array"
	if not _has_property(replay_input, "content_snapshot_paths"):
		return "ReplayRunner.run_replay_with_context requires content_snapshot_paths"
	var content_snapshot_paths = replay_input.get("content_snapshot_paths")
	if typeof(content_snapshot_paths) != TYPE_PACKED_STRING_ARRAY:
		return "ReplayRunner.run_replay_with_context requires PackedStringArray content_snapshot_paths"
	if content_snapshot_paths.is_empty():
		return "ReplayRunner.run_replay_with_context requires non-empty content_snapshot_paths"
	for path_index in range(content_snapshot_paths.size()):
		if String(content_snapshot_paths[path_index]).strip_edges().is_empty():
			return "ReplayRunner.run_replay_with_context content_snapshot_paths[%d] must be non-empty" % path_index
	if _has_property(replay_input, "battle_seed") and typeof(replay_input.get("battle_seed")) != TYPE_INT:
		return "ReplayRunner.run_replay_with_context requires integer battle_seed"
	if not _has_property(replay_input, "command_stream"):
		return "ReplayRunner.run_replay_with_context requires command_stream"
	var command_stream = replay_input.get("command_stream")
	if typeof(command_stream) != TYPE_ARRAY:
		return "ReplayRunner.run_replay_with_context requires Array command_stream"
	for command_index in range(command_stream.size()):
		var command = command_stream[command_index]
		if command == null:
			return "ReplayRunner.run_replay_with_context command_stream[%d] must not be null" % command_index
		if not _has_property(command, "turn_index"):
			return "ReplayRunner.run_replay_with_context command_stream[%d] missing turn_index" % command_index
		if int(command.get("turn_index")) <= 0:
			return "ReplayRunner.run_replay_with_context command_stream[%d] requires turn_index > 0" % command_index
	return ""

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

func _has_property(value, property_name: String) -> bool:
	if value == null or property_name.is_empty():
		return false
	if typeof(value) == TYPE_DICTIONARY:
		return value.has(property_name)
	for property_info in value.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false
