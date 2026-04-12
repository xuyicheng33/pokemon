extends RefCounted
class_name FormalRegistryContracts

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const DEFAULT_CONTRACT_PATH := "res://config/formal_registry_contracts.json"
const MANIFEST_CHARACTER_RUNTIME_BUCKET := "manifest_character_runtime"
const MANIFEST_CHARACTER_DELIVERY_BUCKET := "manifest_character_delivery"
const PAIR_INTERACTION_SPEC_BUCKET := "pair_interaction_spec"

var contract_path_override: String = ""

func required_string_fields_result(bucket_name: String) -> Dictionary:
	return _field_list_result(bucket_name, "required_string_fields")

func required_array_fields_result(bucket_name: String) -> Dictionary:
	return _field_list_result(bucket_name, "required_array_fields")

func required_positive_int_fields_result(bucket_name: String) -> Dictionary:
	return _field_list_result(bucket_name, "required_positive_int_fields", true, true)

func optional_string_fields_result(bucket_name: String) -> Dictionary:
	return _field_list_result(bucket_name, "optional_string_fields", false, true)

func validate_required_fields_result(bucket_name: String, entry: Dictionary, error_prefix: String) -> Dictionary:
	var string_fields_result := required_string_fields_result(bucket_name)
	if not bool(string_fields_result.get("ok", false)):
		return string_fields_result
	for raw_field_name in string_fields_result.get("data", PackedStringArray()):
		var field_name := String(raw_field_name)
		if String(entry.get(field_name, "")).strip_edges().is_empty():
			return _error_result("%s missing %s" % [error_prefix, field_name])
	var array_fields_result := required_array_fields_result(bucket_name)
	if not bool(array_fields_result.get("ok", false)):
		return array_fields_result
	for raw_field_name in array_fields_result.get("data", PackedStringArray()):
		var field_name := String(raw_field_name)
		if not (entry.get(field_name, null) is Array):
			return _error_result("%s missing %s" % [error_prefix, field_name])
	var positive_int_fields_result := required_positive_int_fields_result(bucket_name)
	if not bool(positive_int_fields_result.get("ok", false)):
		return positive_int_fields_result
	for raw_field_name in positive_int_fields_result.get("data", PackedStringArray()):
		var field_name := String(raw_field_name)
		var positive_int_result := _parse_positive_int_result(
			entry.get(field_name, null),
			"%s %s must be positive integer" % [error_prefix, field_name]
		)
		if not bool(positive_int_result.get("ok", false)):
			return positive_int_result
		entry[field_name] = int(positive_int_result.get("data", 0))
	return _ok_result(true)

func load_contracts_result() -> Dictionary:
	var resolved_contract_path := _resolve_resource_path(contract_path_override, DEFAULT_CONTRACT_PATH)
	var file := FileAccess.open(resolved_contract_path, FileAccess.READ)
	if file == null:
		return _error_result("FormalRegistryContracts missing contract file: %s" % resolved_contract_path)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _error_result("FormalRegistryContracts expects top-level dictionary: %s" % resolved_contract_path)
	for bucket_name in [
		MANIFEST_CHARACTER_RUNTIME_BUCKET,
		MANIFEST_CHARACTER_DELIVERY_BUCKET,
		PAIR_INTERACTION_SPEC_BUCKET,
	]:
		var bucket = parsed.get(bucket_name, {})
		if not (bucket is Dictionary):
			return _error_result("FormalRegistryContracts missing dictionary bucket %s: %s" % [bucket_name, resolved_contract_path])
		for field_key in ["required_string_fields", "required_array_fields"]:
			var field_list_result := _read_field_list_result(bucket, field_key, "%s.%s" % [bucket_name, field_key], true)
			if not bool(field_list_result.get("ok", false)):
				return field_list_result
		var positive_int_fields_result := _read_field_list_result(
			bucket,
			"required_positive_int_fields",
			"%s.required_positive_int_fields" % bucket_name,
			true,
			true
		)
		if not bool(positive_int_fields_result.get("ok", false)):
			return positive_int_fields_result
		var optional_fields_result := _read_field_list_result(bucket, "optional_string_fields", "%s.optional_string_fields" % bucket_name, false)
		if not bool(optional_fields_result.get("ok", false)):
			return optional_fields_result
	return _ok_result(parsed.duplicate(true))

func normalize_resource_path(raw_path: String) -> String:
	var trimmed_path := String(raw_path).strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

func _field_list_result(bucket_name: String, field_key: String, required: bool = true, allow_empty: bool = false) -> Dictionary:
	var contracts_result := load_contracts_result()
	if not bool(contracts_result.get("ok", false)):
		return contracts_result
	var contracts: Dictionary = contracts_result.get("data", {})
	var bucket: Dictionary = contracts.get(bucket_name, {})
	return _read_field_list_result(bucket, field_key, "%s.%s" % [bucket_name, field_key], required, allow_empty)

func _read_field_list_result(bucket: Dictionary, field_key: String, label: String, required: bool, allow_empty: bool = false) -> Dictionary:
	if not bucket.has(field_key):
		return _ok_result(PackedStringArray()) if not required else _error_result("FormalRegistryContracts missing %s" % label)
	var raw_fields = bucket.get(field_key, [])
	if not (raw_fields is Array):
		return _error_result("FormalRegistryContracts %s must be array" % label)
	var fields := PackedStringArray()
	for raw_field_name in raw_fields:
		var field_name := String(raw_field_name).strip_edges()
		if field_name.is_empty():
			return _error_result("FormalRegistryContracts %s contains empty field name" % label)
		fields.append(field_name)
	if required and not allow_empty and fields.is_empty():
		return _error_result("FormalRegistryContracts %s must not be empty" % label)
	return _ok_result(fields)

func _parse_positive_int_result(value, error_message: String) -> Dictionary:
	if typeof(value) == TYPE_INT:
		if int(value) > 0:
			return _ok_result(int(value))
		return _error_result(error_message)
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		var int_value := int(float_value)
		if float_value == float(int_value) and int_value > 0:
			return _ok_result(int_value)
	return _error_result(error_message)

func _resolve_resource_path(raw_path: String, default_path: String = "") -> String:
	var normalized_path := normalize_resource_path(raw_path)
	if normalized_path.is_empty():
		return default_path
	return normalized_path

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": ErrorCodesScript.INVALID_BATTLE_SETUP,
		"error_message": error_message,
	}
