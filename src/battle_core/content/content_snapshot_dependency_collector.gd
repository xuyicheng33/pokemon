extends RefCounted
class_name ContentSnapshotDependencyCollector

var signature_static_file_paths := PackedStringArray([
	"res://config/formal_character_capability_catalog.json",
	"res://config/formal_character_manifest.json",
	"res://config/formal_registry_contracts.json",
	"res://src/shared/formal_character_baselines.gd",
	"res://src/shared/formal_character_capability_catalog.gd",
	"res://src/shared/formal_character_manifest.gd",
	"res://src/shared/formal_registry_contracts.gd",
])
var signature_static_dir_paths := PackedStringArray([
	"res://config/formal_character_sources",
	"res://src/battle_core/content",
	"res://src/battle_core/content/formal_validators",
	"res://src/shared/formal_character_baselines",
	"res://src/shared/formal_character_manifest",
])

const STATIC_DIR_TRACKED_EXTENSIONS := {
	"gd": true,
	"json": true,
}

var last_error_message := ""

func collect_tracked_signature_paths(content_snapshot_paths: PackedStringArray) -> Array[String]:
	last_error_message = ""
	var pending_paths: Array[String] = []
	for raw_path in content_snapshot_paths:
		var normalized_path := String(raw_path).strip_edges()
		if normalized_path.is_empty():
			continue
		pending_paths.append(normalized_path)
	if pending_paths.is_empty():
		return []
	var tracked_paths: Array[String] = []
	var seen_paths: Dictionary = {}
	while not pending_paths.is_empty():
		var path := String(pending_paths.pop_back())
		if path.is_empty() or seen_paths.has(path):
			continue
		seen_paths[path] = true
		tracked_paths.append(path)
		var dependency_result := collect_signature_dependency_paths_result(path)
		if not bool(dependency_result.get("ok", false)):
			last_error_message = String(dependency_result.get("error_message", "failed to collect signature dependency paths"))
			return []
		for dependency_path in dependency_result.get("data", []):
			if not seen_paths.has(dependency_path):
				pending_paths.append(dependency_path)
	var static_paths_result := collect_static_signature_paths_result()
	if not bool(static_paths_result.get("ok", false)):
		last_error_message = String(static_paths_result.get("error_message", "failed to collect static signature paths"))
		return []
	for static_path in static_paths_result.get("data", []):
		if static_path.is_empty() or seen_paths.has(static_path):
			continue
		seen_paths[static_path] = true
		tracked_paths.append(static_path)
	tracked_paths.sort()
	return tracked_paths

func collect_static_signature_paths() -> Array[String]:
	var result := collect_static_signature_paths_result()
	return result.get("data", []) if bool(result.get("ok", false)) else []

func collect_static_signature_paths_result() -> Dictionary:
	var tracked_paths: Array[String] = []
	var seen_paths: Dictionary = {}
	for raw_path in signature_static_file_paths:
		var path := String(raw_path).strip_edges()
		if path.is_empty() or seen_paths.has(path):
			continue
		if not FileAccess.file_exists(path):
			return _error_result("missing content snapshot signature file: %s" % path)
		seen_paths[path] = true
		tracked_paths.append(path)
	for raw_dir_path in signature_static_dir_paths:
		var dir_result := collect_static_dir_paths_recursive_result(String(raw_dir_path).strip_edges())
		if not bool(dir_result.get("ok", false)):
			return dir_result
		for path in dir_result.get("data", []):
			if path.is_empty() or seen_paths.has(path):
				continue
			seen_paths[path] = true
			tracked_paths.append(path)
	tracked_paths.sort()
	return _ok_result(tracked_paths)

func collect_static_dir_paths_recursive(dir_path: String) -> Array[String]:
	var result := collect_static_dir_paths_recursive_result(dir_path)
	return result.get("data", []) if bool(result.get("ok", false)) else []

func collect_static_dir_paths_recursive_result(dir_path: String) -> Dictionary:
	if dir_path.is_empty():
		return _ok_result([])
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return _error_result("missing content snapshot signature dir: %s" % dir_path)
	var paths: Array[String] = []
	for raw_subdir_name in dir_access.get_directories():
		var nested_result := collect_static_dir_paths_recursive_result("%s/%s" % [dir_path, String(raw_subdir_name)])
		if not bool(nested_result.get("ok", false)):
			return nested_result
		paths.append_array(nested_result.get("data", []))
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name).strip_edges()
		if not STATIC_DIR_TRACKED_EXTENSIONS.has(file_name.get_extension()):
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	return _ok_result(paths)

func collect_signature_dependency_paths(path: String) -> Array[String]:
	var result := collect_signature_dependency_paths_result(path)
	return result.get("data", []) if bool(result.get("ok", false)) else []

func collect_signature_dependency_paths_result(path: String) -> Dictionary:
	if not path.begins_with("res://") and not path.begins_with("user://"):
		return _ok_result([])
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error_result("missing content snapshot signature source: %s" % path)
	var dependency_paths: Array[String] = []
	for raw_line in file.get_as_text().split("\n"):
		var line := String(raw_line).strip_edges()
		if not line.begins_with("[ext_resource"):
			continue
		var dependency_path := extract_dependency_path(line)
		if not should_track_dependency_path(dependency_path):
			continue
		dependency_paths.append(dependency_path)
	return _ok_result(dependency_paths)

func extract_dependency_path(ext_resource_line: String) -> String:
	var marker := 'path="'
	var start_index := ext_resource_line.find(marker)
	if start_index == -1:
		return ""
	start_index += marker.length()
	var end_index := ext_resource_line.find('"', start_index)
	if end_index == -1:
		return ""
	return ext_resource_line.substr(start_index, end_index - start_index).strip_edges()

func should_track_dependency_path(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("res://content/"):
		return path.ends_with(".tres") or path.ends_with(".res")
	if path.begins_with("user://"):
		return true
	return false

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_message": "",
	}

func _error_result(error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": [],
		"error_message": error_message,
	}
