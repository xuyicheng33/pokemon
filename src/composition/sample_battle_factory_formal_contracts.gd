extends RefCounted
class_name SampleBattleFactoryFormalContracts

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func build_runtime_registry_maps_result(runtime_entries: Array) -> Dictionary:
	var runtime_order: Array = []
	var character_to_unit: Dictionary = {}
	var unit_to_character: Dictionary = {}
	for raw_entry in runtime_entries:
		if not (raw_entry is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory runtime registry contains non-dictionary entry"
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var unit_definition_id := String(entry.get("unit_definition_id", "")).strip_edges()
		if character_id.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory runtime registry entry missing character_id"
			)
		if unit_definition_id.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory runtime registry[%s] missing unit_definition_id" % character_id
			)
		if character_to_unit.has(character_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory runtime registry duplicated character_id: %s" % character_id
			)
		if unit_to_character.has(unit_definition_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory runtime registry duplicated unit_definition_id: %s" % unit_definition_id
			)
		runtime_order.append(character_id)
		character_to_unit[character_id] = unit_definition_id
		unit_to_character[unit_definition_id] = character_id
	return _ok_result({
		"runtime_order": runtime_order,
		"character_to_unit": character_to_unit,
		"unit_to_character": unit_to_character,
	})

func build_delivery_registry_maps_result(delivery_entries: Array) -> Dictionary:
	var delivery_character_ids: Dictionary = {}
	var surface_skill_by_character: Dictionary = {}
	for raw_entry in delivery_entries:
		if not (raw_entry is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry contains non-dictionary entry"
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var surface_smoke_skill_id := String(entry.get("surface_smoke_skill_id", "")).strip_edges()
		if character_id.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry entry missing character_id"
			)
		if delivery_character_ids.has(character_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry duplicated character_id: %s" % character_id
			)
		if surface_smoke_skill_id.is_empty():
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry[%s] missing surface_smoke_skill_id" % character_id
			)
		delivery_character_ids[character_id] = true
		surface_skill_by_character[character_id] = surface_smoke_skill_id
	return _ok_result({
		"delivery_character_ids": delivery_character_ids,
		"surface_skill_by_character": surface_skill_by_character,
	})

func parse_positive_int_result(value, error_message: String) -> Dictionary:
	if typeof(value) == TYPE_INT:
		if int(value) > 0:
			return _ok_result(int(value))
		return _error_result(ErrorCodesScript.INVALID_BATTLE_SETUP, error_message)
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		var int_value := int(float_value)
		if float_value == float(int_value) and int_value > 0:
			return _ok_result(int_value)
	return _error_result(ErrorCodesScript.INVALID_BATTLE_SETUP, error_message)

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
