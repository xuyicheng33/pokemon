extends RefCounted
class_name BattleInputContractHelper

const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")

static func validate_battle_setup_error(battle_setup, operation_label: String) -> String:
	if battle_setup == null:
		return "%s requires battle_setup" % operation_label
	if not _has_property(battle_setup, "sides"):
		return "%s requires battle_setup.sides" % operation_label
	var sides = _read_property(battle_setup, "sides", null)
	if typeof(sides) != TYPE_ARRAY or sides.is_empty():
		return "%s requires battle_setup.sides to be a non-empty Array" % operation_label
	return validate_side_id_error(sides, operation_label)

static func validate_side_id_error(sides: Array, operation_label: String) -> String:
	for issue in _collect_side_issues(sides):
		var issue_kind := String(issue.get("kind", ""))
		var side_index := int(issue.get("side_index", -1))
		var side_id := String(issue.get("side_id", "")).strip_edges()
		match issue_kind:
			"null_side":
				return "%s requires battle_setup.sides[%d]" % [operation_label, side_index]
			"missing_side_id":
				return "%s requires battle_setup.sides[%d].side_id" % [operation_label, side_index]
			"empty_side_id":
				return "%s requires battle_setup.sides[%d].side_id to be non-empty" % [operation_label, side_index]
			"duplicate_side_id":
				return "%s duplicated battle_setup side_id: %s" % [operation_label, side_id]
	return ""

static func collect_side_id_errors(sides: Array, subject_label: String) -> Array[String]:
	var errors: Array[String] = []
	for issue in _collect_side_issues(sides):
		var issue_kind := String(issue.get("kind", ""))
		var side_index := int(issue.get("side_index", -1))
		var side_id := String(issue.get("side_id", "")).strip_edges()
		match issue_kind:
			"null_side":
				errors.append("%s.sides[%d] must not be null" % [subject_label, side_index])
			"missing_side_id":
				errors.append("%s.sides[%d].side_id must exist" % [subject_label, side_index])
			"empty_side_id":
				errors.append("%s.sides[%d].side_id must be non-empty" % [subject_label, side_index])
			"duplicate_side_id":
				errors.append("%s duplicated side_id: %s" % [subject_label, side_id])
	return errors

static func validate_content_snapshot_paths_error(content_snapshot_paths, operation_label: String) -> String:
	if typeof(content_snapshot_paths) != TYPE_PACKED_STRING_ARRAY:
		return "%s requires PackedStringArray content_snapshot_paths" % operation_label
	if content_snapshot_paths.is_empty():
		return "%s requires non-empty content_snapshot_paths" % operation_label
	for path_index in range(content_snapshot_paths.size()):
		var path := String(content_snapshot_paths[path_index]).strip_edges()
		if path.is_empty():
			return "%s content_snapshot_paths[%d] must be non-empty" % [operation_label, path_index]
	return ""

static func validate_command_stream_error(command_stream, operation_label: String) -> String:
	if typeof(command_stream) != TYPE_ARRAY:
		return "%s requires Array command_stream" % operation_label
	for command_index in range(command_stream.size()):
		var command = command_stream[command_index]
		if command == null:
			return "%s command_stream[%d] must not be null" % [operation_label, command_index]
		if not _has_property(command, "turn_index"):
			return "%s command_stream[%d] missing turn_index" % [operation_label, command_index]
		if int(_read_property(command, "turn_index", 0)) <= 0:
			return "%s command_stream[%d] requires turn_index > 0" % [operation_label, command_index]
	return ""

static func validate_replay_input_error(replay_input, operation_label: String) -> String:
	if replay_input == null:
		return "%s requires replay_input" % operation_label
	if not _has_property(replay_input, "battle_setup"):
		return "%s requires battle_setup" % operation_label
	var battle_setup_error := validate_battle_setup_error(
		_read_property(replay_input, "battle_setup", null),
		operation_label
	)
	if not battle_setup_error.is_empty():
		return battle_setup_error
	if not _has_property(replay_input, "content_snapshot_paths"):
		return "%s requires content_snapshot_paths" % operation_label
	var content_snapshot_paths_error := validate_content_snapshot_paths_error(
		_read_property(replay_input, "content_snapshot_paths", null),
		operation_label
	)
	if not content_snapshot_paths_error.is_empty():
		return content_snapshot_paths_error
	if _has_property(replay_input, "battle_seed") and typeof(_read_property(replay_input, "battle_seed", null)) != TYPE_INT:
		return "%s requires integer battle_seed" % operation_label
	if not _has_property(replay_input, "command_stream"):
		return "%s requires command_stream" % operation_label
	return validate_command_stream_error(
		_read_property(replay_input, "command_stream", null),
		operation_label
	)

static func _collect_side_issues(sides: Array) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var seen_side_ids: Dictionary = {}
	for side_index in range(sides.size()):
		var side_setup = sides[side_index]
		if side_setup == null:
			issues.append({"kind": "null_side", "side_index": side_index})
			continue
		if not _has_property(side_setup, "side_id"):
			issues.append({"kind": "missing_side_id", "side_index": side_index})
			continue
		var side_id := String(_read_property(side_setup, "side_id", "")).strip_edges()
		if side_id.is_empty():
			issues.append({"kind": "empty_side_id", "side_index": side_index})
			continue
		if seen_side_ids.has(side_id):
			issues.append({"kind": "duplicate_side_id", "side_index": side_index, "side_id": side_id})
			continue
		seen_side_ids[side_id] = true
	return issues

static func _has_property(value, property_name: String) -> bool:
	return PropertyAccessHelperScript.has_property(value, property_name)

static func _read_property(value, property_name: String, default_value = null):
	return PropertyAccessHelperScript.read_property(value, property_name, default_value)
