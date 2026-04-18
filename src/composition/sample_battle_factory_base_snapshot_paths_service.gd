extends RefCounted
class_name SampleBattleFactoryBaseSnapshotPathsService

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

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

func build_base_snapshot_paths(base_dirs: Array) -> Dictionary:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	for raw_dir_path in base_dirs:
		var dir_result := collect_tres_paths_result(String(raw_dir_path))
		if not bool(dir_result.get("ok", false)):
			return dir_result
		append_unique_paths(paths, seen, dir_result.get("data", []))
	paths.sort()
	return ResultEnvelopeHelperScript.ok(PackedStringArray(paths))

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
	return ResultEnvelopeHelperScript.ok(paths)

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
	return ResultEnvelopeHelperScript.ok(paths)

func append_unique_paths(paths: Array[String], seen: Dictionary, candidate_paths) -> void:
	for path in candidate_paths:
		append_unique_path(paths, seen, String(path))

func append_unique_path(paths: Array[String], seen: Dictionary, path: String) -> void:
	if path.is_empty() or seen.has(path):
		return
	seen[path] = true
	paths.append(path)

func normalize_res_path(raw_path: String) -> String:
	var trimmed_path := raw_path.strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

func _error_result(message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, message)
