extends RefCounted
class_name ResultEnvelopeHelper

static func ok(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

static func error(error_code: Variant, error_message: String, data = null) -> Dictionary:
	return {
		"ok": false,
		"data": data,
		"error_code": error_code,
		"error_message": error_message,
	}

static func unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	if envelope == null:
		return _simple_error("%s returned null envelope" % label)
	for key_name in ["ok", "data", "error_code", "error_message"]:
		if not envelope.has(key_name):
			return _simple_error("%s missing envelope key: %s" % [label, key_name])
	if bool(envelope.get("ok", false)):
		if envelope.get("error_code", null) != null or envelope.get("error_message", null) != null:
			return _simple_error("%s success envelope should not expose error payload" % label)
		return {"ok": true, "data": envelope.get("data", null)}
	var error_code = envelope.get("error_code", null)
	var error_message := String(envelope.get("error_message", ""))
	return _simple_error(
		"%s failed: %s (%s)" % [label, error_message, str(error_code)],
		error_code,
		error_message
	)

static func _simple_error(message: String, error_code: Variant = null, error_message: String = "") -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"error_code": error_code,
		"error_message": error_message if not error_message.is_empty() else message,
	}
