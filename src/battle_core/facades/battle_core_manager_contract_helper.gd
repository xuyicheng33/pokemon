extends RefCounted
class_name BattleCoreManagerContractHelper

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

static func ok(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

static func error(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}

static func dependency_error(missing_dependency: String) -> Variant:
	if missing_dependency.is_empty():
		return null
	return error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: %s" % missing_dependency)

static func validate_create_session_payload(init_payload) -> Variant:
	if init_payload == null:
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires input payload")
	if typeof(init_payload) != TYPE_DICTIONARY:
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires Dictionary payload")
	if not init_payload.has("battle_setup"):
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires battle_setup")
	var battle_setup_error = _validate_battle_setup(
		init_payload.get("battle_setup", null),
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"BattleCoreManager.create_session"
	)
	if battle_setup_error != null:
		return battle_setup_error
	if not init_payload.has("content_snapshot_paths"):
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires content_snapshot_paths")
	var content_paths_error = _validate_content_snapshot_paths(
		init_payload.get("content_snapshot_paths", null),
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"BattleCoreManager.create_session"
	)
	if content_paths_error != null:
		return content_paths_error
	if init_payload.has("battle_seed") and typeof(init_payload.get("battle_seed", null)) != TYPE_INT:
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires integer battle_seed")
	return null

static func validate_replay_input(replay_input) -> Variant:
	if replay_input == null:
		return error(ErrorCodesScript.INVALID_REPLAY_INPUT, "ReplayRunner.run_replay_with_context requires replay_input")
	if not _has_property(replay_input, "battle_setup"):
		return error(ErrorCodesScript.INVALID_REPLAY_INPUT, "ReplayRunner.run_replay_with_context requires battle_setup")
	var battle_setup_error = _validate_battle_setup(
		replay_input.get("battle_setup"),
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"ReplayRunner.run_replay_with_context"
	)
	if battle_setup_error != null:
		return battle_setup_error
	if not _has_property(replay_input, "content_snapshot_paths"):
		return error(ErrorCodesScript.INVALID_REPLAY_INPUT, "ReplayRunner.run_replay_with_context requires content_snapshot_paths")
	var content_paths_error = _validate_content_snapshot_paths(
		replay_input.get("content_snapshot_paths"),
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"ReplayRunner.run_replay_with_context"
	)
	if content_paths_error != null:
		return content_paths_error
	if _has_property(replay_input, "battle_seed") and typeof(replay_input.get("battle_seed")) != TYPE_INT:
		return error(ErrorCodesScript.INVALID_REPLAY_INPUT, "ReplayRunner.run_replay_with_context requires integer battle_seed")
	if not _has_property(replay_input, "command_stream"):
		return error(ErrorCodesScript.INVALID_REPLAY_INPUT, "ReplayRunner.run_replay_with_context requires command_stream")
	var command_stream = replay_input.get("command_stream")
	if typeof(command_stream) != TYPE_ARRAY:
		return error(ErrorCodesScript.INVALID_REPLAY_INPUT, "ReplayRunner.run_replay_with_context requires Array command_stream")
	for command_index in range(command_stream.size()):
		var command = command_stream[command_index]
		if command == null:
			return error(
				ErrorCodesScript.INVALID_REPLAY_INPUT,
				"ReplayRunner.run_replay_with_context command_stream[%d] must not be null" % command_index
			)
		if not _has_property(command, "turn_index"):
			return error(
				ErrorCodesScript.INVALID_REPLAY_INPUT,
				"ReplayRunner.run_replay_with_context command_stream[%d] missing turn_index" % command_index
			)
		if int(command.get("turn_index")) <= 0:
			return error(
				ErrorCodesScript.INVALID_REPLAY_INPUT,
				"ReplayRunner.run_replay_with_context command_stream[%d] requires turn_index > 0" % command_index
			)
	return null

static func get_session_result(sessions: Dictionary, session_id: String) -> Dictionary:
	if session_id.is_empty():
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager requires non-empty session_id")
	var session = sessions.get(session_id, null)
	if session == null:
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager unknown battle session: %s" % session_id)
	return ok(session)

static func validate_session_runtime_result(session) -> Variant:
	if session == null or not session.has_method("validate_runtime_result"):
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	return session.validate_runtime_result()

static func resolve_turn_failure_result(session) -> Variant:
	if session == null or session.battle_state == null or session.battle_state.battle_result == null:
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	var battle_result = session.battle_state.battle_result
	if not bool(battle_result.finished):
		return null
	var reason := String(battle_result.reason)
	if not reason.begins_with("invalid_"):
		return null
	return error(reason, "BattleCoreManager run_turn terminated invalid battle: %s" % reason)

static func normalize_command_input(raw_command) -> Dictionary:
	if raw_command == null:
		return error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "BattleCoreManager.run_turn received null command")
	if typeof(raw_command) == TYPE_DICTIONARY and raw_command.has("ok") and raw_command.has("data"):
		if not bool(raw_command.get("ok", false)):
			return error(
				raw_command.get("error_code", ErrorCodesScript.INVALID_COMMAND_PAYLOAD),
				raw_command.get("error_message", "BattleCoreManager.run_turn received invalid command envelope")
			)
		if raw_command.get("data", null) == null:
			return error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "BattleCoreManager.run_turn command envelope missing data")
		return ok(raw_command.get("data", null))
	return ok(raw_command)

static func service_error(service, fallback_code: String, fallback_message: String) -> Dictionary:
	var resolved_code: String = fallback_code
	var resolved_message: String = fallback_message
	if service != null and service.has_method("error_state"):
		var state: Dictionary = service.error_state()
		var service_error_code = state.get("code", null)
		var raw_service_error_message = state.get("message", "")
		var service_error_message := "" if raw_service_error_message == null else str(raw_service_error_message)
		if service_error_code != null:
			resolved_code = str(service_error_code)
		if not service_error_message.is_empty():
			resolved_message = service_error_message
	return error(resolved_code, resolved_message)

static func _validate_battle_setup(battle_setup, error_code: String, operation_label: String) -> Variant:
	if battle_setup == null:
		return error(error_code, "%s requires battle_setup" % operation_label)
	if not _has_property(battle_setup, "sides"):
		return error(error_code, "%s requires battle_setup.sides" % operation_label)
	var sides = battle_setup.get("sides")
	if typeof(sides) != TYPE_ARRAY or sides.is_empty():
		return error(error_code, "%s requires battle_setup.sides to be a non-empty Array" % operation_label)
	return null

static func _validate_content_snapshot_paths(content_snapshot_paths, error_code: String, operation_label: String) -> Variant:
	if typeof(content_snapshot_paths) != TYPE_PACKED_STRING_ARRAY:
		return error(error_code, "%s requires PackedStringArray content_snapshot_paths" % operation_label)
	if content_snapshot_paths.is_empty():
		return error(error_code, "%s requires non-empty content_snapshot_paths" % operation_label)
	for path_index in range(content_snapshot_paths.size()):
		var path := String(content_snapshot_paths[path_index]).strip_edges()
		if path.is_empty():
			return error(
				error_code,
				"%s content_snapshot_paths[%d] must be non-empty" % [operation_label, path_index]
			)
	return null

static func _has_property(value, property_name: String) -> bool:
	if value == null or property_name.is_empty():
		return false
	if typeof(value) == TYPE_DICTIONARY:
		return value.has(property_name)
	for property_info in value.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false
