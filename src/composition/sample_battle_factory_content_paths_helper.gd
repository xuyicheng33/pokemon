extends RefCounted
class_name SampleBattleFactoryContentPathsHelper

const FormalCharacterRegistryScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_registry.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func build_snapshot_paths(base_dirs: Array) -> Dictionary:
	return _build_snapshot_paths_from_registry(base_dirs, {}, false)

func build_snapshot_paths_for_setup(base_dirs: Array, battle_setup) -> Dictionary:
	if battle_setup == null:
		return _error_result("SampleBattleFactory requires battle_setup to build setup-scoped content snapshot paths")
	return _build_snapshot_paths_from_registry(base_dirs, _collect_unit_definition_ids(battle_setup), true)

func _build_snapshot_paths_from_registry(base_dirs: Array, included_unit_definition_ids: Dictionary, restrict_registry_entries: bool) -> Dictionary:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	for raw_dir_path in base_dirs:
		var dir_result := collect_tres_paths_result(String(raw_dir_path))
		if not bool(dir_result.get("ok", false)):
			return dir_result
		_append_unique_paths(paths, seen, dir_result.get("data", []))
	var registry_result: Dictionary = FormalCharacterRegistryScript.load_entries()
	var registry_error := String(registry_result.get("error", ""))
	if not registry_error.is_empty():
		return _error_result("SampleBattleFactory failed to load formal character registry: %s" % registry_error)
	for raw_entry in registry_result.get("entries", []):
		if not (raw_entry is Dictionary):
			return _error_result("SampleBattleFactory formal character registry entry must be Dictionary")
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var unit_definition_id := String(entry.get("unit_definition_id", "")).strip_edges()
		if restrict_registry_entries and not included_unit_definition_ids.has(unit_definition_id):
			continue
		var required_content_paths = entry.get("required_content_paths", [])
		if not (required_content_paths is Array):
			return _error_result("SampleBattleFactory registry[%s] missing required_content_paths" % character_id)
		for raw_rel_path in required_content_paths:
			var resource_path := _normalize_res_path(String(raw_rel_path))
			if resource_path.is_empty():
				return _error_result("SampleBattleFactory registry[%s] has empty required_content_paths entry" % character_id)
			if not ResourceLoader.exists(resource_path):
				return _error_result("SampleBattleFactory missing content snapshot resource: %s" % resource_path)
			_append_unique_path(paths, seen, resource_path)
	paths.sort()
	return _ok_result(PackedStringArray(paths))

func _collect_unit_definition_ids(battle_setup) -> Dictionary:
	var unit_definition_ids: Dictionary = {}
	var sides = battle_setup.get("sides") if battle_setup != null else []
	if not (sides is Array):
		return unit_definition_ids
	for side_setup in sides:
		if side_setup == null:
			continue
		for raw_unit_definition_id in side_setup.unit_definition_ids:
			var unit_definition_id := String(raw_unit_definition_id).strip_edges()
			if unit_definition_id.is_empty():
				continue
			unit_definition_ids[unit_definition_id] = true
	return unit_definition_ids

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return _error_result("SampleBattleFactory missing snapshot dir: %s" % dir_path)
	var paths: Array[String] = []
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name)
		if file_name.get_extension() != "tres":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	paths.sort()
	return _ok_result(paths)

func collect_tres_paths_recursive(dir_path: String) -> Array[String]:
	var dir_access := DirAccess.open(dir_path)
	assert(dir_access != null, "SampleBattleFactory missing snapshot dir: %s" % dir_path)
	var paths: Array[String] = []
	for raw_subdir_name in dir_access.get_directories():
		paths.append_array(collect_tres_paths_recursive("%s/%s" % [dir_path, String(raw_subdir_name)]))
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name)
		if file_name.get_extension() != "tres":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	paths.sort()
	return paths

func _append_unique_paths(paths: Array[String], seen: Dictionary, candidate_paths: Array) -> void:
	for path in candidate_paths:
		_append_unique_path(paths, seen, String(path))

func _append_unique_path(paths: Array[String], seen: Dictionary, path: String) -> void:
	if path.is_empty() or seen.has(path):
		return
	seen[path] = true
	paths.append(path)

func _normalize_res_path(raw_path: String) -> String:
	var trimmed_path := raw_path.strip_edges()
	return "" if trimmed_path.is_empty() else (trimmed_path if trimmed_path.begins_with("res://") else "res://%s" % trimmed_path)

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
		"error_message": message,
	}
