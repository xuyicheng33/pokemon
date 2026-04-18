extends RefCounted
class_name ResultEnvelopeHelper

static func ok(data) -> Dictionary:
	return _envelope(true, data, null, null)

static func error(error_code: Variant, error_message: String, data = null) -> Dictionary:
	return _envelope(false, data, error_code, error_message)

static func unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	if envelope == null:
		return error(null, "%s returned null envelope" % label)
	for key_name in ["ok", "data", "error_code", "error_message"]:
		if not envelope.has(key_name):
			return error(null, "%s missing envelope key: %s" % [label, key_name])
	if bool(envelope.get("ok", false)):
		if envelope.get("error_code", null) != null or envelope.get("error_message", null) != null:
			return error(null, "%s success envelope should not expose error payload" % label)
		return ok(envelope.get("data", null))
	var error_code = envelope.get("error_code", null)
	var detail := String(envelope.get("error_message", "unknown error")).strip_edges()
	if detail.is_empty():
		detail = "unknown error"
	return error(error_code, "%s failed: %s (%s)" % [label, detail, str(error_code)])

static func _envelope(ok_value: bool, data, error_code: Variant, error_message: Variant) -> Dictionary:
	return {
		"ok": ok_value,
		"data": data,
		"error_code": error_code,
		"error_message": error_message,
	}
