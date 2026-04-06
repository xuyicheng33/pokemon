extends RefCounted
class_name FormalCharacterRegistry

const REGISTRY_PATH := "res://config/formal_character_delivery_registry.json"

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
	var resolved_registry_path := _resolve_registry_path(registry_path)
	var file := FileAccess.open(resolved_registry_path, FileAccess.READ)
	if file == null:
		return _error_result("FormalCharacterRegistry missing delivery registry: %s" % resolved_registry_path)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return _error_result("FormalCharacterRegistry expects top-level array: %s" % resolved_registry_path)
	var entries: Array = []
	var seen_character_ids: Dictionary = {}
	for raw_entry in parsed:
		if not (raw_entry is Dictionary):
			return _error_result("FormalCharacterRegistry expects dictionary entries")
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			return _error_result("FormalCharacterRegistry entry missing character_id")
		if seen_character_ids.has(character_id):
			return _error_result("FormalCharacterRegistry duplicated character_id: %s" % character_id)
		seen_character_ids[character_id] = true
		if String(entry.get("display_name", "")).strip_edges().is_empty():
			return _error_result("FormalCharacterRegistry[%s] missing display_name" % character_id)
		if String(entry.get("design_doc", "")).strip_edges().is_empty():
			return _error_result("FormalCharacterRegistry[%s] missing design_doc" % character_id)
		if String(entry.get("adjustment_doc", "")).strip_edges().is_empty():
			return _error_result("FormalCharacterRegistry[%s] missing adjustment_doc" % character_id)
		if String(entry.get("suite_path", "")).strip_edges().is_empty():
			return _error_result("FormalCharacterRegistry[%s] missing suite_path" % character_id)
		if not (entry.get("required_suite_paths", null) is Array):
			return _error_result("FormalCharacterRegistry[%s] missing required_suite_paths" % character_id)
		if not (entry.get("required_test_names", null) is Array):
			return _error_result("FormalCharacterRegistry[%s] missing required_test_names" % character_id)
		if not (entry.get("design_needles", null) is Array):
			return _error_result("FormalCharacterRegistry[%s] missing design_needles" % character_id)
		if not (entry.get("adjustment_needles", null) is Array):
			return _error_result("FormalCharacterRegistry[%s] missing adjustment_needles" % character_id)
		entries.append(entry.duplicate(true))
	return {
		"ok": true,
		"entries": entries,
		"error": "",
	}

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

func _resolve_registry_path(registry_path: String) -> String:
	var normalized_path := String(registry_path).strip_edges()
	if normalized_path.is_empty():
		return REGISTRY_PATH
	return normalized_path if normalized_path.begins_with("res://") or normalized_path.begins_with("user://") else "res://%s" % normalized_path

func _error_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"entries": [],
		"error": message,
	}
