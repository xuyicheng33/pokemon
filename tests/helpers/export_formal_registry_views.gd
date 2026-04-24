extends SceneTree

const DEFAULT_SOURCE_DIR := "res://config/formal_character_sources"
const CHARACTER_DESCRIPTOR_KIND := "formal_character_source"
const SHARED_DESCRIPTOR_KIND := "formal_registry_shared"
const RESOURCE_FILE_EXTENSIONS := {
	"res": true,
	"tres": true,
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("EXPORT_FORMAL_REGISTRY_VIEWS_FAILED: missing output path")
		quit(1)
		return
	var output_path := String(args[0]).strip_edges()
	if output_path.is_empty():
		printerr("EXPORT_FORMAL_REGISTRY_VIEWS_FAILED: empty output path")
		quit(1)
		return
	var source_dir := DEFAULT_SOURCE_DIR
	if args.size() >= 2:
		source_dir = _normalize_resource_path(String(args[1]).strip_edges(), DEFAULT_SOURCE_DIR)
	var views_result := _build_views_result(source_dir)
	if not bool(views_result.get("ok", false)):
		printerr("EXPORT_FORMAL_REGISTRY_VIEWS_FAILED: %s" % String(views_result.get("error_message", "unknown error")))
		quit(1)
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("EXPORT_FORMAL_REGISTRY_VIEWS_FAILED: cannot open output path: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(views_result.get("data", {}), "  "))
	file.flush()
	file.close()
	quit(0)

func _build_views_result(source_dir: String) -> Dictionary:
	var descriptors_result := _load_descriptors_result(source_dir)
	if not bool(descriptors_result.get("ok", false)):
		return descriptors_result
	var descriptors: Dictionary = descriptors_result.get("data", {})
	var characters_result := _build_character_entries_result(descriptors.get("character_entries", []))
	if not bool(characters_result.get("ok", false)):
		return characters_result
	var shared_descriptor: Dictionary = descriptors.get("shared_descriptor", {})
	var matchups_result := _build_matchups_result(shared_descriptor.get("matchups", null))
	if not bool(matchups_result.get("ok", false)):
		return matchups_result
	var capabilities_result := _build_capability_entries_result(shared_descriptor.get("capabilities", null))
	if not bool(capabilities_result.get("ok", false)):
		return capabilities_result
	return _ok_result({
		"manifest": {
			"characters": characters_result.get("data", []).duplicate(true),
			"matchups": matchups_result.get("data", {}).duplicate(true),
		},
		"capability_catalog": {
			"capabilities": capabilities_result.get("data", []).duplicate(true),
		},
	})

func _load_descriptors_result(source_dir: String) -> Dictionary:
	var dir = DirAccess.open(source_dir)
	if dir == null:
		return _error_result("missing source dir: %s" % source_dir)
	var descriptor_paths: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			descriptor_paths.append("%s/%s" % [source_dir, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	descriptor_paths.sort()
	if descriptor_paths.is_empty():
		return _error_result("no source descriptors found under: %s" % source_dir)
	var shared_descriptor: Dictionary = {}
	var character_entries: Array = []
	for descriptor_path in descriptor_paths:
		var descriptor_result := _load_json_descriptor_result(descriptor_path)
		if not bool(descriptor_result.get("ok", false)):
			return descriptor_result
		var descriptor: Dictionary = descriptor_result.get("data", {})
		var descriptor_kind := String(descriptor.get("descriptor_kind", "")).strip_edges()
		match descriptor_kind:
			SHARED_DESCRIPTOR_KIND:
				if not shared_descriptor.is_empty():
					return _error_result("duplicate shared descriptor: %s" % descriptor_path)
				shared_descriptor = descriptor.duplicate(true)
			CHARACTER_DESCRIPTOR_KIND:
				var character = descriptor.get("character", null)
				if not (character is Dictionary):
					return _error_result("character descriptor missing character object: %s" % descriptor_path)
				character_entries.append(character.duplicate(true))
			_:
				return _error_result("unknown descriptor_kind in %s: %s" % [descriptor_path, descriptor_kind])
	if shared_descriptor.is_empty():
		return _error_result("missing shared descriptor under: %s" % source_dir)
	return _ok_result({
		"shared_descriptor": shared_descriptor,
		"character_entries": character_entries,
	})

func _load_json_descriptor_result(descriptor_path: String) -> Dictionary:
	var file := FileAccess.open(descriptor_path, FileAccess.READ)
	if file == null:
		return _error_result("cannot open descriptor: %s" % descriptor_path)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _error_result("descriptor must be top-level dictionary: %s" % descriptor_path)
	return _ok_result(parsed)

func _build_character_entries_result(raw_character_entries: Array) -> Dictionary:
	if raw_character_entries.is_empty():
		return _error_result("shared registry must define at least one character descriptor")
	var character_entries: Array = []
	var seen_character_ids: Dictionary = {}
	for raw_entry in raw_character_entries:
		if not (raw_entry is Dictionary):
			return _error_result("character descriptor entry must be dictionary")
		var entry: Dictionary = raw_entry.duplicate(true)
		if entry.has("required_content_paths"):
			return _error_result("character source must not declare required_content_paths directly: %s" % String(entry.get("character_id", "")))
		var character_id := String(entry.get("character_id", "")).strip_edges()
		if character_id.is_empty():
			return _error_result("character source missing character_id")
		if seen_character_ids.has(character_id):
			return _error_result("duplicate character source: %s" % character_id)
		seen_character_ids[character_id] = true
		var content_roots_result := _expand_content_roots_result(entry.get("content_roots", null), character_id)
		if not bool(content_roots_result.get("ok", false)):
			return content_roots_result
		entry.erase("content_roots")
		entry["required_content_paths"] = content_roots_result.get("data", []).duplicate(true)
		var owned_pair_specs_result := _normalize_owned_pair_interaction_specs_result(entry.get("owned_pair_interaction_specs", null), character_id)
		if not bool(owned_pair_specs_result.get("ok", false)):
			return owned_pair_specs_result
		entry["owned_pair_interaction_specs"] = owned_pair_specs_result.get("data", []).duplicate(true)
		var validator_script_path := String(entry.get("content_validator_script_path", "")).strip_edges()
		if validator_script_path.is_empty():
			return _error_result("formal character source missing content_validator_script_path: %s" % character_id)
		character_entries.append(entry)
	return _ok_result(character_entries)

func _normalize_owned_pair_interaction_specs_result(raw_specs, character_id: String) -> Dictionary:
	if not (raw_specs is Array):
		return _error_result("formal character source owned_pair_interaction_specs must be array: %s" % character_id)
	var normalized_specs: Array = []
	for spec_index in range(raw_specs.size()):
		var raw_spec = raw_specs[spec_index]
		if not (raw_spec is Dictionary):
			return _error_result("formal character source owned_pair_interaction_specs[%d] must be dictionary: %s" % [spec_index, character_id])
		var spec: Dictionary = raw_spec.duplicate(true)
		for field_name in ["owner_as_initiator_battle_seed", "owner_as_responder_battle_seed"]:
			if not spec.has(field_name):
				continue
			var numeric_value = spec.get(field_name, null)
			if numeric_value is float and floorf(numeric_value) == numeric_value:
				spec[field_name] = int(numeric_value)
		normalized_specs.append(spec)
	return _ok_result(normalized_specs)

func _expand_content_roots_result(raw_content_roots, character_id: String) -> Dictionary:
	if not (raw_content_roots is Array) or raw_content_roots.is_empty():
		return _error_result("formal character source missing content_roots: %s" % character_id)
	var required_content_paths: Array[String] = []
	var seen_paths: Dictionary = {}
	for raw_root in raw_content_roots:
		var content_root := String(raw_root).strip_edges()
		if content_root.is_empty():
			return _error_result("formal character source has empty content_root: %s" % character_id)
		var resource_root := _normalize_resource_path(content_root)
		if FileAccess.file_exists(resource_root):
			_register_required_path(required_content_paths, seen_paths, _relative_project_path(resource_root))
			continue
		var collect_result := _collect_resource_files_result(resource_root)
		if not bool(collect_result.get("ok", false)):
			return _error_result("%s for %s" % [String(collect_result.get("error_message", "content root error")), character_id])
		for rel_path in collect_result.get("data", []):
			_register_required_path(required_content_paths, seen_paths, String(rel_path))
	required_content_paths.sort()
	return _ok_result(required_content_paths)

func _collect_resource_files_result(resource_root: String) -> Dictionary:
	var dir = DirAccess.open(resource_root)
	if dir == null:
		return _error_result("missing content_root: %s" % resource_root)
	var collected_paths: Array[String] = []
	var stack: Array[String] = [resource_root]
	while not stack.is_empty():
		var current_dir: String = stack.pop_back()
		var nested_dir = DirAccess.open(current_dir)
		if nested_dir == null:
			return _error_result("missing nested content_root: %s" % current_dir)
		nested_dir.list_dir_begin()
		var file_name := nested_dir.get_next()
		while not file_name.is_empty():
			if file_name.begins_with("."):
				file_name = nested_dir.get_next()
				continue
			var child_path := "%s/%s" % [current_dir, file_name]
			if nested_dir.current_is_dir():
				stack.append(child_path)
			elif RESOURCE_FILE_EXTENSIONS.has(file_name.get_extension().to_lower()):
				collected_paths.append(_relative_project_path(child_path))
			file_name = nested_dir.get_next()
		nested_dir.list_dir_end()
	collected_paths.sort()
	return _ok_result(collected_paths)

func _build_matchups_result(raw_matchups) -> Dictionary:
	if not (raw_matchups is Array):
		return _error_result("shared descriptor matchups must be array")
	var matchups: Dictionary = {}
	for entry_index in range(raw_matchups.size()):
		var raw_entry = raw_matchups[entry_index]
		if not (raw_entry is Dictionary):
			return _error_result("shared descriptor matchups[%d] must be dictionary" % entry_index)
		var entry: Dictionary = raw_entry
		var matchup_id := String(entry.get("matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			return _error_result("shared descriptor matchup[%d] missing matchup_id" % entry_index)
		if matchups.has(matchup_id):
			return _error_result("duplicate shared descriptor matchup_id: %s" % matchup_id)
		var matchup_entry := {
			"p1_units": _copy_required_array_result(entry.get("p1_units", null), "matchup %s p1_units" % matchup_id),
			"p2_units": _copy_required_array_result(entry.get("p2_units", null), "matchup %s p2_units" % matchup_id),
		}
		if matchup_entry["p1_units"] == null or matchup_entry["p2_units"] == null:
			return _error_result("shared descriptor matchup %s missing p1_units or p2_units" % matchup_id)
		if entry.has("test_only"):
			var test_only = entry.get("test_only", null)
			if not (test_only is bool):
				return _error_result("shared descriptor matchup %s test_only must be boolean" % matchup_id)
			if bool(test_only):
				matchup_entry["test_only"] = true
		matchups[matchup_id] = matchup_entry
	return _ok_result(matchups)

func _build_capability_entries_result(raw_capabilities) -> Dictionary:
	if not (raw_capabilities is Array):
		return _error_result("shared descriptor capabilities must be array")
	var capability_entries: Array = []
	var seen_capability_ids: Dictionary = {}
	for entry_index in range(raw_capabilities.size()):
		var raw_entry = raw_capabilities[entry_index]
		if not (raw_entry is Dictionary):
			return _error_result("shared descriptor capabilities[%d] must be dictionary" % entry_index)
		var entry: Dictionary = raw_entry.duplicate(true)
		var capability_id := String(entry.get("capability_id", "")).strip_edges()
		if capability_id.is_empty():
			return _error_result("shared descriptor capabilities[%d] missing capability_id" % entry_index)
		if seen_capability_ids.has(capability_id):
			return _error_result("duplicate capability source: %s" % capability_id)
		seen_capability_ids[capability_id] = true
		capability_entries.append(entry)
	return _ok_result(capability_entries)

func _copy_required_array_result(raw_value, label: String):
	if not (raw_value is Array) or raw_value.is_empty():
		return null
	return raw_value.duplicate(true)

func _register_required_path(required_content_paths: Array[String], seen_paths: Dictionary, rel_path: String) -> void:
	var normalized_rel_path := _relative_project_path(_normalize_resource_path(rel_path))
	if normalized_rel_path.is_empty() or seen_paths.has(normalized_rel_path):
		return
	seen_paths[normalized_rel_path] = true
	required_content_paths.append(normalized_rel_path)

func _relative_project_path(resource_path: String) -> String:
	var normalized_path := _normalize_resource_path(resource_path)
	if normalized_path.begins_with("res://"):
		return normalized_path.trim_prefix("res://")
	return normalized_path

func _normalize_resource_path(raw_path: String, default_path: String = "") -> String:
	var trimmed_path := String(raw_path).strip_edges()
	if trimmed_path.is_empty():
		trimmed_path = String(default_path).strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_message": "",
	}

func _error_result(error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_message": error_message,
	}
