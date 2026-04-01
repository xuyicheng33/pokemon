extends RefCounted
class_name BattleCoreManagerContractHelper

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func ok(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func error(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}

func dependency_error(missing_dependency: String):
	if missing_dependency.is_empty():
		return null
	return error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: %s" % missing_dependency)

func validate_create_session_payload(init_payload):
	if init_payload == null:
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires input payload")
	if not init_payload.has("battle_setup"):
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires battle_setup")
	if not init_payload.has("content_snapshot_paths"):
		return error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.create_session requires content_snapshot_paths")
	return null

func get_session_result(sessions: Dictionary, session_id: String) -> Dictionary:
	if session_id.is_empty():
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager requires non-empty session_id")
	var session = sessions.get(session_id, null)
	if session == null:
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager unknown battle session: %s" % session_id)
	return ok(session)

func validate_session_runtime_result(session) -> Variant:
	if session == null or session.container == null or session.battle_state == null:
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	var runtime_guard_service = session.container.runtime_guard_service
	if runtime_guard_service == null:
		return error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: runtime_guard_service")
	var invalid_code = runtime_guard_service.validate_runtime_state(session.battle_state, session.content_index)
	if invalid_code == null:
		return null
	return error(str(invalid_code), "BattleCoreManager runtime state invalid: %s" % str(invalid_code))

func resolve_turn_failure_result(session) -> Variant:
	if session == null or session.battle_state == null or session.battle_state.battle_result == null:
		return error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
	var battle_result = session.battle_state.battle_result
	if not bool(battle_result.finished):
		return null
	var reason := String(battle_result.reason)
	if not reason.begins_with("invalid_"):
		return null
	return error(reason, "BattleCoreManager run_turn terminated invalid battle: %s" % reason)

func normalize_command_input(raw_command) -> Dictionary:
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

func service_error(service, fallback_code: String, fallback_message: String) -> Dictionary:
	var resolved_code: String = fallback_code
	var resolved_message: String = fallback_message
	if service != null:
		var service_error_code = service.get("last_error_code")
		var raw_service_error_message = service.get("last_error_message")
		var service_error_message := "" if raw_service_error_message == null else str(raw_service_error_message)
		if service_error_code != null:
			resolved_code = str(service_error_code)
		if not service_error_message.is_empty():
			resolved_message = service_error_message
	return error(resolved_code, resolved_message)
