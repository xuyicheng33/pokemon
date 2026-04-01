extends RefCounted
class_name ManagerContractTestHelper

func validate_snapshot_shape(public_snapshot: Dictionary) -> String:
	if typeof(public_snapshot.get("sides", null)) != TYPE_ARRAY:
		return "missing sides"
	if typeof(public_snapshot.get("field", null)) != TYPE_DICTIONARY:
		return "missing field"
	if typeof(public_snapshot.get("prebattle_public_teams", null)) != TYPE_ARRAY:
		return "missing prebattle_public_teams"
	for side_snapshot in public_snapshot["sides"]:
		if typeof(side_snapshot) != TYPE_DICTIONARY:
			return "side snapshot must be Dictionary"
		if typeof(side_snapshot.get("team_units", null)) != TYPE_ARRAY:
			return "side snapshot missing team_units"
		for unit_snapshot in side_snapshot["team_units"]:
			if typeof(unit_snapshot) != TYPE_DICTIONARY:
				return "team unit snapshot must be Dictionary"
			if typeof(unit_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
				return "team unit snapshot missing combat_type_ids"
	for side_snapshot in public_snapshot["prebattle_public_teams"]:
		if typeof(side_snapshot) != TYPE_DICTIONARY:
			return "prebattle side snapshot must be Dictionary"
		if typeof(side_snapshot.get("units", null)) != TYPE_ARRAY:
			return "prebattle side snapshot missing units"
		for unit_snapshot in side_snapshot["units"]:
			if typeof(unit_snapshot) != TYPE_DICTIONARY:
				return "prebattle unit snapshot must be Dictionary"
			if typeof(unit_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
				return "prebattle unit snapshot missing combat_type_ids"
	return ""

func find_side_snapshot(public_snapshot: Dictionary, side_id: String) -> Dictionary:
	for side_snapshot in public_snapshot.get("sides", []):
		if str(side_snapshot.get("side_id", "")) == side_id:
			return side_snapshot
	return {}

func contains_key_recursive(value, expected_key: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value.keys():
			if str(key) == expected_key:
				return true
			if contains_key_recursive(value[key], expected_key):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for element in value:
			if contains_key_recursive(element, expected_key):
				return true
	return false

func contains_private_instance_id_key(value) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value.keys():
			var key_text := String(key)
			if key_text == "unit_instance_id" or key_text.ends_with("_instance_id"):
				return true
			if contains_private_instance_id_key(value[key]):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for element in value:
			if contains_private_instance_id_key(element):
				return true
	return false

func contains_any_key_recursive(value, keys: PackedStringArray) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value.keys():
			if keys.has(str(key)):
				return true
			if contains_any_key_recursive(value[key], keys):
				return true
	elif typeof(value) == TYPE_ARRAY:
		for element in value:
			if contains_any_key_recursive(element, keys):
				return true
	return false

func unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	if envelope == null:
		return {"ok": false, "error": "%s returned null envelope" % label}
	var required_keys := ["ok", "data", "error_code", "error_message"]
	for key in required_keys:
		if not envelope.has(key):
			return {"ok": false, "error": "%s missing envelope key: %s" % [label, key]}
	if bool(envelope.get("ok", false)):
		if envelope.get("error_code", null) != null or envelope.get("error_message", null) != null:
			return {"ok": false, "error": "%s success envelope should not expose error payload" % label}
		return {"ok": true, "data": envelope.get("data", null)}
	if envelope.get("data", null) != null:
		return {"ok": false, "error": "%s failure envelope must set data=null" % label}
	if envelope.get("error_code", null) == null or String(envelope.get("error_message", "")).is_empty():
		return {"ok": false, "error": "%s failure envelope missing error payload" % label}
	return {"ok": false, "error": "%s failed: %s (%s)" % [label, String(envelope.get("error_message", "")), String(envelope.get("error_code", ""))]}

func expect_failure_code(
	envelope: Dictionary,
	label: String,
	error_code: String,
	message_substring: String = ""
) -> Dictionary:
	if envelope == null:
		return {"ok": false, "error": "%s returned null envelope" % label}
	var required_keys := ["ok", "data", "error_code", "error_message"]
	for key in required_keys:
		if not envelope.has(key):
			return {"ok": false, "error": "%s missing envelope key: %s" % [label, key]}
	if bool(envelope.get("ok", false)):
		return {"ok": false, "error": "%s should fail-fast" % label}
	if envelope.get("data", null) != null:
		return {"ok": false, "error": "%s failure envelope must set data=null" % label}
	if String(envelope.get("error_code", "")) != error_code:
		return {"ok": false, "error": "%s error_code mismatch: expected %s got %s" % [label, error_code, str(envelope.get("error_code", null))]}
	if not message_substring.is_empty() and String(envelope.get("error_message", "")).find(message_substring) == -1:
		return {"ok": false, "error": "%s should mention %s in error_message" % [label, message_substring]}
	return {"ok": true}
