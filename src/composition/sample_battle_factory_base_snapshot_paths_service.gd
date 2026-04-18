extends RefCounted
class_name SampleBattleFactoryBaseSnapshotPathsService

const SnapshotDirCollectorScript := preload("res://src/composition/sample_battle_factory_snapshot_dir_collector.gd")

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

var _dir_collector = SnapshotDirCollectorScript.new()

func build_base_snapshot_paths(base_dirs: Array) -> Dictionary:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	for raw_dir_path in base_dirs:
		var dir_result := collect_tres_paths_result(String(raw_dir_path))
		if not bool(dir_result.get("ok", false)):
			return dir_result
		append_unique_paths(paths, seen, dir_result.get("data", []))
	paths.sort()
	return _ok_result(PackedStringArray(paths))

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return _dir_collector.collect_tres_paths_result(dir_path)

func collect_tres_paths_recursive_result(dir_path: String) -> Dictionary:
	return _dir_collector.collect_tres_paths_recursive_result(dir_path)

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

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}
