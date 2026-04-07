extends RefCounted
class_name SampleBattleFactoryContentPathsHelper

const RuntimeRegistryLoaderScript := preload("res://src/composition/sample_battle_factory_runtime_registry_loader.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const BASE_CONTENT_SNAPSHOT_DIRS = [
	"res://content/battle_formats",
	"res://content/combat_types",
	"res://content/units",
	"res://content/skills",
	"res://content/passive_items",
	"res://content/effects",
	"res://content/fields",
	"res://content/passive_skills",
	"res://content/samples",
]

var registry_path_override: String = ""
var baseline_unit_definition_ids: PackedStringArray = PackedStringArray()

func build_snapshot_paths(base_dirs: Array) -> Dictionary:
	return _build_snapshot_paths_from_registry(base_dirs, {}, false)

func build_base_snapshot_paths(base_dirs: Array) -> Dictionary:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	for raw_dir_path in base_dirs:
		var dir_result := collect_tres_paths_result(String(raw_dir_path))
		if not bool(dir_result.get("ok", false)):
			return dir_result
		_append_unique_paths(paths, seen, dir_result.get("data", []))
	paths.sort()
	return _ok_result(PackedStringArray(paths))

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
	if restrict_registry_entries and _included_units_are_baseline_only(included_unit_definition_ids):
		paths.sort()
		return _ok_result(PackedStringArray(paths))
	var registry_result: Dictionary = _load_registry_entries()
	var registry_error := String(registry_result.get("error", ""))
	if not registry_error.is_empty():
		return _error_result("SampleBattleFactory failed to load formal character runtime registry: %s" % registry_error)
	for raw_entry in registry_result.get("entries", []):
		if not (raw_entry is Dictionary):
			return _error_result("SampleBattleFactory formal character runtime registry entry must be Dictionary")
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

func _included_units_are_baseline_only(included_unit_definition_ids: Dictionary) -> bool:
	if included_unit_definition_ids.is_empty():
		return true
	var baseline_lookup: Dictionary = {}
	for raw_unit_definition_id in baseline_unit_definition_ids:
		baseline_lookup[String(raw_unit_definition_id)] = true
	if baseline_lookup.is_empty():
		return false
	for raw_unit_definition_id in included_unit_definition_ids.keys():
		if not baseline_lookup.has(String(raw_unit_definition_id)):
			return false
	return true

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
	var result := collect_tres_paths_recursive_result(dir_path)
	if not bool(result.get("ok", false)):
		return []
	return result.get("data", [])

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return _error_result("SampleBattleFactory missing snapshot dir: %s" % dir_path)
	var paths: Array[String] = []
	for raw_subdir_name in dir_access.get_directories():
		var child_result := collect_tres_paths_recursive_result("%s/%s" % [dir_path, String(raw_subdir_name)])
		if not bool(child_result.get("ok", false)):
			return child_result
		paths.append_array(child_result.get("data", []))
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name)
		if file_name.get_extension() != "tres":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	paths.sort()
	return _ok_result(paths)

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
	return "" if trimmed_path.is_empty() else (trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path)

func _load_registry_entries() -> Dictionary:
	var loader = RuntimeRegistryLoaderScript.new()
	loader.registry_path_override = registry_path_override
	var entries_result: Dictionary = loader.load_entries_for_snapshot_result()
	if bool(entries_result.get("ok", false)):
		return {
			"entries": entries_result.get("data", []),
			"error": "",
		}
	return {
		"entries": [],
		"error": String(entries_result.get("error_message", "unknown error")),
	}

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
