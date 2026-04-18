extends RefCounted
class_name FormalCharacterRegistry

const FormalAccessScript := preload("res://src/composition/sample_battle_factory_formal_access.gd")
const REGISTRY_PATH := "res://config/formal_character_manifest.json"

func load_entries() -> Array:
	var load_result := load_entries_result()
	assert(bool(load_result.get("ok", false)), "FormalCharacterRegistry failed to load delivery registry entries: %s" % String(load_result.get("error", "unknown error")))
	return load_result.get("entries", [])

func load_entries_from_path(registry_path: String) -> Array:
	var load_result := load_entries_from_path_result(registry_path)
	assert(bool(load_result.get("ok", false)), "FormalCharacterRegistry failed to load delivery registry entries: %s" % String(load_result.get("error", "unknown error")))
	return load_result.get("entries", [])

func load_entries_result() -> Dictionary:
	return load_entries_from_path_result(REGISTRY_PATH)

func load_entries_from_path_result(registry_path: String) -> Dictionary:
	var formal_access = FormalAccessScript.new()
	formal_access.registry_path_override = registry_path
	var result: Dictionary = formal_access.load_delivery_entries_result()
	if not bool(result.get("ok", false)):
		return _error_result(String(result.get("error_message", "unknown error")))
	return {
		"ok": true,
		"entries": result.get("data", []),
		"error": "",
	}

func _error_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"entries": [],
		"error": message,
	}
