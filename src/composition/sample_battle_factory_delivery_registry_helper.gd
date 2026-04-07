extends RefCounted
class_name SampleBattleFactoryDeliveryRegistryHelper

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const REGISTRY_PATH := "res://config/formal_character_delivery_registry.json"

var registry_path_override: String = ""

func load_entries_result() -> Dictionary:
	var resolved_registry_path := _resolve_registry_path(registry_path_override)
	var file := FileAccess.open(resolved_registry_path, FileAccess.READ)
	if file == null:
		return error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory missing formal character delivery registry: %s" % resolved_registry_path
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory expects top-level array delivery registry: %s" % resolved_registry_path
		)
	var entries: Array = []
	var seen_character_ids: Dictionary = {}
	for raw_entry in parsed:
		if not (raw_entry is Dictionary):
			return error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory expects dictionary delivery registry entries"
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			return error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry entry missing character_id"
			)
		if seen_character_ids.has(character_id):
			return error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"SampleBattleFactory delivery registry duplicated character_id: %s" % character_id
			)
		seen_character_ids[character_id] = true
		for required_key in ["display_name", "design_doc", "adjustment_doc", "surface_smoke_skill_id", "suite_path"]:
			if String(entry.get(required_key, "")).strip_edges().is_empty():
				return error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory delivery registry[%s] missing %s" % [character_id, required_key]
				)
		for required_array_key in ["required_suite_paths", "required_test_names", "design_needles", "adjustment_needles"]:
			if not (entry.get(required_array_key, null) is Array):
				return error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"SampleBattleFactory delivery registry[%s] missing %s" % [character_id, required_array_key]
				)
		entries.append(entry.duplicate(true))
	return ok_result(entries)

func _resolve_registry_path(registry_path: String) -> String:
	var normalized_path := String(registry_path).strip_edges()
	if normalized_path.is_empty():
		return REGISTRY_PATH
	return normalized_path if normalized_path.begins_with("res://") or normalized_path.begins_with("user://") else "res://%s" % normalized_path

func ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
