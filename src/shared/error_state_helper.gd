extends RefCounted
class_name ErrorStateHelper

static func error_state(target) -> Dictionary:
	return {
		"code": _read_code(target),
		"message": _read_message(target),
	}

static func clear(target) -> void:
	_write(target, null, "")

static func fail(target, error_code: Variant, error_message: String) -> void:
	_write(target, error_code, error_message)

static func capture_envelope(target, envelope: Dictionary, fallback_code: Variant = null, fallback_message: String = "") -> void:
	if envelope == null:
		_write(target, fallback_code, fallback_message)
		return
	var error_code = envelope.get("error_code", fallback_code)
	var error_message = _normalized_message(envelope.get("error_message", fallback_message))
	if error_message.is_empty() and not String(fallback_message).is_empty():
		error_message = String(fallback_message)
	_write(target, error_code, error_message)

static func capture_state(target, error_state_payload: Dictionary, fallback_code: Variant = null, fallback_message: String = "") -> void:
	if error_state_payload == null:
		_write(target, fallback_code, fallback_message)
		return
	var error_code = error_state_payload.get("code", fallback_code)
	var error_message = _normalized_message(error_state_payload.get("message", fallback_message))
	if error_message.is_empty() and not String(fallback_message).is_empty():
		error_message = String(fallback_message)
	_write(target, error_code, error_message)

static func capture_service_state(target, service, fallback_code: Variant = null, fallback_message: String = "") -> void:
	if service == null or not service.has_method("error_state"):
		_write(target, fallback_code, fallback_message)
		return
	capture_state(target, service.error_state(), fallback_code, fallback_message)

static func _write(target, error_code: Variant, error_message: Variant) -> void:
	if target == null:
		return
	target.set("last_error_code", error_code)
	target.set("last_error_message", _normalized_message(error_message))

static func _read_code(target) -> Variant:
	return target.get("last_error_code") if target != null else null

static func _read_message(target) -> String:
	if target == null:
		return ""
	return _normalized_message(target.get("last_error_message"))

static func _normalized_message(raw_message = "") -> String:
	return "" if raw_message == null else str(raw_message)
