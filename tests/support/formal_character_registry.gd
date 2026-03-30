extends RefCounted
class_name FormalCharacterRegistry

const REGISTRY_PATH := "res://docs/records/formal_character_registry.json"

func load_entries() -> Array:
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	assert(file != null, "FormalCharacterRegistry missing registry: %s" % REGISTRY_PATH)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(parsed is Array, "FormalCharacterRegistry expects top-level array: %s" % REGISTRY_PATH)
	var entries: Array = []
	for raw_entry in parsed:
		assert(raw_entry is Dictionary, "FormalCharacterRegistry expects dictionary entries")
		entries.append(raw_entry)
	return entries

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
