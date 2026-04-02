extends RefCounted
class_name BattleCoreSession

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var session_id: String = ""
var container = null
var battle_state = null
var content_index = null

func validate_runtime_result() -> Variant:
    if not _is_ready():
        return _error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
    var runtime_guard_service = _get_container_service("runtime_guard_service")
    if runtime_guard_service == null:
        return _error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: runtime_guard_service")
    var invalid_code = runtime_guard_service.validate_runtime_state(battle_state, content_index)
    if invalid_code == null:
        return null
    return _error(str(invalid_code), "BattleCoreManager runtime state invalid: %s" % str(invalid_code))

func get_legal_actions_result(side_id: String) -> Dictionary:
    if not _is_ready():
        return _error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
    var legal_action_service = _get_container_service("legal_action_service")
    if legal_action_service == null:
        return _error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: legal_action_service")
    var legal_actions = legal_action_service.get_legal_actions(battle_state, side_id, content_index)
    if legal_actions == null:
        return _service_error(
            legal_action_service,
            ErrorCodesScript.INVALID_STATE_CORRUPTION,
            "BattleCoreManager failed to build legal action set"
        )
    return _ok(legal_actions)

func run_turn_result(commands: Array) -> Dictionary:
    if not _is_ready():
        return _error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
    var turn_loop_controller = _get_container_service("turn_loop_controller")
    if turn_loop_controller == null:
        return _error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: turn_loop_controller")
    turn_loop_controller.run_turn(battle_state, content_index, commands)
    return _ok(true)

func get_event_log_snapshot_result() -> Dictionary:
    if not _is_ready():
        return _error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager session is incomplete")
    var battle_logger = _get_container_service("battle_logger")
    if battle_logger == null:
        return _error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager missing dependency: battle_logger")
    return _ok(battle_logger.snapshot())

func dispose() -> void:
    if container != null and container.has_method("dispose"):
        container.dispose()
    container = null
    battle_state = null
    content_index = null

func _is_ready() -> bool:
    return container != null and battle_state != null and content_index != null

func _get_container_service(service_name: String):
    if container == null:
        return null
    return container.get(service_name)

func _ok(data) -> Dictionary:
    return {
        "ok": true,
        "data": data,
        "error_code": null,
        "error_message": null,
    }

func _error(error_code: String, error_message: String) -> Dictionary:
    return {
        "ok": false,
        "data": null,
        "error_code": error_code,
        "error_message": error_message,
    }

func _service_error(service, fallback_code: String, fallback_message: String) -> Dictionary:
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
    return _error(resolved_code, resolved_message)
