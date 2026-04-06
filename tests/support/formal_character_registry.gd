extends RefCounted
class_name FormalCharacterRegistry

const REGISTRY_PATH := "res://config/formal_character_registry.json"
const RuntimeRegistryScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")

func load_entries() -> Array:
	var load_result: Dictionary = RuntimeRegistryScript.load_entries()
	var error_message := String(load_result.get("error", ""))
	assert(error_message.is_empty(), "FormalCharacterRegistry failed to load runtime registry entries: %s" % error_message)
	return load_result.get("entries", [])

func build_suite_instances() -> Array:
	var suites: Array = []
	for raw_entry in load_entries():
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", ""))
		var suite_path := String(entry.get("suite_path", ""))
		assert(not character_id.is_empty(), "FormalCharacterRegistry entry missing character_id")
		assert(not suite_path.is_empty(), "FormalCharacterRegistry[%s] missing suite_path" % character_id)
		var suite_script = load("res://%s" % suite_path)
		assert(suite_script != null, "FormalCharacterRegistry failed to load suite: %s" % suite_path)
		suites.append(suite_script.new())
	return suites
