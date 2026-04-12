extends RefCounted
class_name ContentPayloadValidator

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")
const PayloadValidatorRegistryScript := preload("res://src/battle_core/content/payload_validator_registry.gd")

var _validator_instances: Dictionary = {}

func missing_registered_validator_keys() -> PackedStringArray:
	var missing_keys := PackedStringArray()
	for raw_validator_key in PayloadContractRegistryScript.registered_validator_keys():
		var validator_key := String(raw_validator_key).strip_edges()
		var validator = validator_for_key(validator_key)
		if validator != null:
			continue
		missing_keys.append(validator_key)
	return missing_keys

func stale_registered_validator_keys() -> PackedStringArray:
	var stale_keys := PackedStringArray()
	var contract_validator_keys: Dictionary = {}
	for raw_validator_key in PayloadContractRegistryScript.registered_validator_keys():
		contract_validator_keys[String(raw_validator_key).strip_edges()] = true
	for raw_validator_key in PayloadValidatorRegistryScript.registered_validator_keys():
		var validator_key := String(raw_validator_key).strip_edges()
		if validator_key.is_empty() or contract_validator_keys.has(validator_key):
			continue
		stale_keys.append(validator_key)
	return stale_keys

func validator_for_key(validator_key: String):
	var normalized_key := validator_key.strip_edges()
	if normalized_key.is_empty():
		return null
	if _validator_instances.has(normalized_key):
		return _validator_instances[normalized_key]
	var validator_script = PayloadValidatorRegistryScript.validator_script_for_key(normalized_key)
	if validator_script == null:
		return null
	var validator = validator_script.new()
	if validator == null or not validator.has_method("validate"):
		return null
	_validator_instances[normalized_key] = validator
	return validator

func validate_effect_refs(errors: Array, label: String, effect_ids: PackedStringArray, effects: Dictionary) -> void:
	for effect_id in effect_ids:
		if not effects.has(effect_id):
			errors.append("%s missing effect: %s" % [label, effect_id])

func validate_payload(errors: Array, effect_id: String, payload, content_index) -> void:
	if payload == null:
		errors.append("effect[%s].payloads contains null" % effect_id)
		return
	var validator_key := PayloadContractRegistryScript.validator_key_for_payload(payload)
	if validator_key.is_empty():
		errors.append("effect[%s].payloads invalid type: %s" % [effect_id, payload])
		return
	var validator = validator_for_key(validator_key)
	if validator == null:
		errors.append("effect[%s].payloads missing validator dispatcher: %s" % [effect_id, validator_key])
		return
	validator.validate(errors, effect_id, payload, content_index, self)
