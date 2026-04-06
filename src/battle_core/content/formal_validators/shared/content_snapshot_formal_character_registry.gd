extends RefCounted
class_name ContentSnapshotFormalCharacterRegistry

const REGISTRY_PATH := "res://config/formal_character_runtime_registry.json"

static func load_entries() -> Dictionary:
	return load_entries_from_path(REGISTRY_PATH)

static func load_entries_from_path(registry_path: String) -> Dictionary:
	var resolved_registry_path := _resolve_registry_path(registry_path)
	var file := FileAccess.open(resolved_registry_path, FileAccess.READ)
	if file == null:
		return {
			"entries": [],
			"error": "ContentSnapshotFormalCharacterRegistry missing registry: %s" % resolved_registry_path,
		}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return {
			"entries": [],
			"error": "ContentSnapshotFormalCharacterRegistry expects top-level array: %s" % resolved_registry_path,
		}
	var entries: Array = []
	var seen_character_ids: Dictionary = {}
	var seen_unit_definition_ids: Dictionary = {}
	for raw_entry in parsed:
		if not (raw_entry is Dictionary):
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry expects dictionary entries",
			}
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry entry missing character_id",
			}
		if seen_character_ids.has(character_id):
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry duplicated character_id: %s" % character_id,
			}
		seen_character_ids[character_id] = true
		var unit_definition_id := String(entry.get("unit_definition_id", "")).strip_edges()
		if unit_definition_id.is_empty():
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry[%s] missing unit_definition_id" % character_id,
			}
		if seen_unit_definition_ids.has(unit_definition_id):
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry duplicated unit_definition_id: %s" % unit_definition_id,
			}
		seen_unit_definition_ids[unit_definition_id] = true
		var matchup_id := String(entry.get("formal_setup_matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry[%s] missing formal_setup_matchup_id" % character_id,
			}
		if not entry.has("required_content_paths"):
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry[%s] missing required_content_paths" % character_id,
			}
		var required_content_paths = entry.get("required_content_paths", [])
		if not (required_content_paths is Array):
			return {
				"entries": [],
				"error": "ContentSnapshotFormalCharacterRegistry[%s] missing required_content_paths" % character_id,
			}
		for raw_rel_path in required_content_paths:
			if String(raw_rel_path).strip_edges().is_empty():
				return {
					"entries": [],
					"error": "ContentSnapshotFormalCharacterRegistry[%s] has empty required_content_paths entry" % character_id,
				}
		var validator_path := String(entry.get("content_validator_script_path", "")).strip_edges()
		if not validator_path.is_empty():
			var resolved_validator_path := validator_path if validator_path.begins_with("res://") else "res://%s" % validator_path
			if not ResourceLoader.exists(resolved_validator_path):
				return {
					"entries": [],
					"error": "ContentSnapshotFormalCharacterRegistry[%s] missing validator: %s" % [character_id, resolved_validator_path],
				}
		entries.append(entry.duplicate(true))
	return {
		"entries": entries,
		"error": "",
	}

static func build_validator_descriptors() -> Dictionary:
	return build_validator_descriptors_from_path(REGISTRY_PATH)

static func build_validator_descriptors_from_path(registry_path: String) -> Dictionary:
	var load_result := load_entries_from_path(registry_path)
	var registry_error := String(load_result.get("error", ""))
	if not registry_error.is_empty():
		return {
			"descriptors": [],
			"error": registry_error,
		}
	var descriptors: Array = []
	for raw_entry in load_result.get("entries", []):
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var validator_path := String(entry.get("content_validator_script_path", "")).strip_edges()
		if validator_path.is_empty():
			continue
		var resolved_validator_path := validator_path if validator_path.begins_with("res://") else "res://%s" % validator_path
		descriptors.append({
			"character_id": character_id,
			"unit_definition_id": String(entry.get("unit_definition_id", "")).strip_edges(),
			"content_validator_script_path": resolved_validator_path,
			"entry": entry.duplicate(true),
		})
	return {
		"descriptors": descriptors,
		"error": "",
	}

static func instantiate_validator_descriptor(descriptor: Dictionary) -> Dictionary:
	var character_id := String(descriptor.get("character_id", "")).strip_edges()
	var validator_path := String(descriptor.get("content_validator_script_path", "")).strip_edges()
	if validator_path.is_empty():
		return {
			"validator": null,
			"error": "ContentSnapshotFormalCharacterRegistry[%s] missing validator path" % character_id,
		}
	var validator_script = load(validator_path)
	if validator_script == null:
		return {
			"validator": null,
			"error": "ContentSnapshotFormalCharacterRegistry[%s] failed to load validator: %s" % [character_id, validator_path],
		}
	if not (validator_script is Script) or not validator_script.can_instantiate():
		return {
			"validator": null,
			"error": "ContentSnapshotFormalCharacterRegistry[%s] validator is not instantiable" % character_id,
		}
	var validator_instance = validator_script.new()
	if validator_instance == null or not validator_instance.has_method("validate"):
		return {
			"validator": null,
			"error": "ContentSnapshotFormalCharacterRegistry[%s] failed to instantiate validator" % character_id,
		}
	return {
		"validator": validator_instance,
		"error": "",
	}

static func build_validator_instances() -> Dictionary:
	return build_validator_instances_from_path(REGISTRY_PATH)

static func build_validator_instances_from_path(registry_path: String) -> Dictionary:
	var descriptor_result := build_validator_descriptors_from_path(registry_path)
	var registry_error := String(descriptor_result.get("error", ""))
	if not registry_error.is_empty():
		return {
			"validators": [],
			"error": registry_error,
		}
	var validators: Array = []
	for raw_descriptor in descriptor_result.get("descriptors", []):
		if not (raw_descriptor is Dictionary):
			continue
		var instantiate_result := instantiate_validator_descriptor(raw_descriptor)
		var instantiate_error := String(instantiate_result.get("error", ""))
		if not instantiate_error.is_empty():
			return {
				"validators": [],
				"error": instantiate_error,
			}
		var validator = instantiate_result.get("validator", null)
		if validator != null:
			validators.append(validator)
	return {
		"validators": validators,
		"error": "",
	}

static func _resolve_registry_path(registry_path: String) -> String:
	var normalized_path := String(registry_path).strip_edges()
	if normalized_path.is_empty():
		return REGISTRY_PATH
	return normalized_path if normalized_path.begins_with("res://") or normalized_path.begins_with("user://") else "res://%s" % normalized_path
