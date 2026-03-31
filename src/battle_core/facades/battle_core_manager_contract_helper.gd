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
