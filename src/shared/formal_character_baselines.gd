extends RefCounted
class_name FormalCharacterBaselines

const BaselineLoaderScript := preload("res://src/shared/formal_character_baselines/formal_character_baseline_loader.gd")
const ERROR_MESSAGE_KEY := "__formal_baseline_error_message"

static func character_ids() -> PackedStringArray:
	return BaselineLoaderScript.character_ids()

static func descriptor_error_message(descriptor) -> String:
	if not (descriptor is Dictionary):
		return ""
	return String(descriptor.get(ERROR_MESSAGE_KEY, "")).strip_edges()

static func unit_contract(character_id: String, label_override: String = "") -> Dictionary:
	var baseline_result := BaselineLoaderScript.baseline_result(character_id)
	if not bool(baseline_result.get("ok", false)):
		return _error_descriptor(String(baseline_result.get("error_message", "unknown formal baseline error")))
	return _resolve_descriptor(
		baseline_result.get("data").unit_contract(),
		label_override,
		"FormalCharacterBaselines[%s] missing unit contract" % character_id.strip_edges()
	)

static func skill_contract(character_id: String, skill_id: String, label_override: String = "") -> Dictionary:
	var descriptor_result := _find_descriptor_result(
		_skill_contract_pool(character_id),
		"skill_id",
		skill_id,
		"FormalCharacterBaselines[%s] missing skill descriptor: %s" % [character_id.strip_edges(), skill_id.strip_edges()]
	)
	if not bool(descriptor_result.get("ok", false)):
		return _error_descriptor(String(descriptor_result.get("error_message", "unknown formal baseline error")))
	return _resolve_descriptor(descriptor_result.get("data", {}), label_override)

static func skill_contracts(character_id: String, skill_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(
		_skill_contract_pool(character_id),
		"skill_id",
		skill_ids,
		"skill",
		character_id
	)

static func passive_contract(character_id: String, passive_skill_id: String, label_override: String = "") -> Dictionary:
	var descriptor_result := _find_descriptor_result(
		_passive_contract_pool(character_id),
		"passive_skill_id",
		passive_skill_id,
		"FormalCharacterBaselines[%s] missing passive descriptor: %s" % [character_id.strip_edges(), passive_skill_id.strip_edges()]
	)
	if not bool(descriptor_result.get("ok", false)):
		return _error_descriptor(String(descriptor_result.get("error_message", "unknown formal baseline error")))
	return _resolve_descriptor(descriptor_result.get("data", {}), label_override)

static func passive_contracts(character_id: String, passive_skill_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(
		_passive_contract_pool(character_id),
		"passive_skill_id",
		passive_skill_ids,
		"passive",
		character_id
	)

static func effect_contract(character_id: String, effect_id: String, label_override: String = "") -> Dictionary:
	var descriptor_result := _find_descriptor_result(
		_effect_contract_pool(character_id),
		"effect_id",
		effect_id,
		"FormalCharacterBaselines[%s] missing effect descriptor: %s" % [character_id.strip_edges(), effect_id.strip_edges()]
	)
	if not bool(descriptor_result.get("ok", false)):
		return _error_descriptor(String(descriptor_result.get("error_message", "unknown formal baseline error")))
	return _resolve_descriptor(descriptor_result.get("data", {}), label_override)

static func effect_contracts(character_id: String, effect_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(
		_effect_contract_pool(character_id),
		"effect_id",
		effect_ids,
		"effect",
		character_id
	)

static func field_contract(character_id: String, field_id: String, label_override: String = "") -> Dictionary:
	var descriptor_result := _find_descriptor_result(
		_field_contract_pool(character_id),
		"field_id",
		field_id,
		"FormalCharacterBaselines[%s] missing field descriptor: %s" % [character_id.strip_edges(), field_id.strip_edges()]
	)
	if not bool(descriptor_result.get("ok", false)):
		return _error_descriptor(String(descriptor_result.get("error_message", "unknown formal baseline error")))
	return _resolve_descriptor(descriptor_result.get("data", {}), label_override)

static func field_contracts(character_id: String, field_ids = []) -> Array[Dictionary]:
	return _resolve_descriptor_array(
		_field_contract_pool(character_id),
		"field_id",
		field_ids,
		"field",
		character_id
	)

static func _skill_contract_pool(character_id: String):
	var baseline_result := BaselineLoaderScript.baseline_result(character_id, "skill contract lookup")
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	var baseline = baseline_result.get("data")
	var descriptors: Array[Dictionary] = baseline.regular_skill_contracts()
	descriptors.append(baseline.ultimate_skill_contract())
	return _ok_result(descriptors)

static func _passive_contract_pool(character_id: String):
	var baseline_result := BaselineLoaderScript.baseline_result(character_id, "passive contract lookup")
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	return _ok_result([baseline_result.get("data").passive_skill_contract()])

static func _effect_contract_pool(character_id: String):
	var baseline_result := BaselineLoaderScript.baseline_result(character_id, "effect contract lookup")
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	return _ok_result(baseline_result.get("data").effect_contracts())

static func _field_contract_pool(character_id: String):
	var baseline_result := BaselineLoaderScript.baseline_result(character_id, "field contract lookup")
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	return _ok_result(baseline_result.get("data").field_contracts())

static func _resolve_descriptor(raw_descriptor: Dictionary, label_override: String = "", error_message: String = "") -> Dictionary:
	if raw_descriptor.is_empty():
		return _error_descriptor(error_message if not error_message.is_empty() else "FormalCharacterBaselines descriptor must not be empty")
	var descriptor: Dictionary = raw_descriptor.duplicate(true)
	if not label_override.is_empty():
		descriptor["label"] = label_override
	return descriptor

static func _resolve_descriptor_array(descriptor_pool_result, id_key: String, requested_ids, descriptor_kind: String, character_id: String) -> Array[Dictionary]:
	if descriptor_pool_result is Dictionary and not bool(descriptor_pool_result.get("ok", false)):
		return [_error_descriptor(String(descriptor_pool_result.get("error_message", "unknown formal baseline error")))]
	var descriptor_pool: Array = descriptor_pool_result.get("data", [])
	var resolved_ids := PackedStringArray(requested_ids)
	if resolved_ids.is_empty():
		for raw_descriptor in descriptor_pool:
			var descriptor: Dictionary = raw_descriptor
			resolved_ids.append(String(descriptor.get(id_key, "")))
	var descriptors: Array[Dictionary] = []
	for raw_id in resolved_ids:
		var requested_id := String(raw_id)
		var descriptor_result := _find_descriptor_result(
			_ok_result(descriptor_pool),
			id_key,
			requested_id,
			"FormalCharacterBaselines[%s] missing %s descriptor: %s" % [character_id.strip_edges(), descriptor_kind, requested_id.strip_edges()]
		)
		if not bool(descriptor_result.get("ok", false)):
			descriptors.append(_error_descriptor(String(descriptor_result.get("error_message", "unknown formal baseline error"))))
			continue
		descriptors.append(_resolve_descriptor(descriptor_result.get("data", {})))
	return descriptors

static func _find_descriptor_result(descriptor_pool_result, id_key: String, requested_id: String, error_message: String) -> Dictionary:
	if descriptor_pool_result is Dictionary and not bool(descriptor_pool_result.get("ok", false)):
		return descriptor_pool_result
	var descriptor_pool: Array = descriptor_pool_result.get("data", [])
	var normalized_id := requested_id.strip_edges()
	if normalized_id.is_empty():
		return _error_result("FormalCharacterBaselines lookup %s must not be empty" % id_key)
	for raw_descriptor in descriptor_pool:
		var descriptor: Dictionary = raw_descriptor
		if String(descriptor.get(id_key, "")) == normalized_id:
			return _ok_result(descriptor)
	return _error_result(error_message)

static func _error_descriptor(error_message: String) -> Dictionary:
	return {ERROR_MESSAGE_KEY: error_message.strip_edges()}

static func _ok_result(data) -> Dictionary:
	return {"ok": true, "data": data, "error_message": ""}

static func _error_result(error_message: String) -> Dictionary:
	return {"ok": false, "data": null, "error_message": error_message.strip_edges()}
