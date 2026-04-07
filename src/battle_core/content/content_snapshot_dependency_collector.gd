extends RefCounted
class_name ContentSnapshotDependencyCollector

var signature_static_file_paths := PackedStringArray([
	"res://config/formal_character_manifest.json",
])
var signature_static_dir_paths := PackedStringArray([
	"res://src/battle_core/content",
	"res://src/battle_core/content/formal_validators",
])

func collect_tracked_signature_paths(content_snapshot_paths: PackedStringArray) -> Array[String]:
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
		for dependency_path in collect_signature_dependency_paths(path):
			if not seen_paths.has(dependency_path):
				pending_paths.append(dependency_path)
	for static_path in collect_static_signature_paths():
		if static_path.is_empty() or seen_paths.has(static_path):
			continue
		seen_paths[static_path] = true
		tracked_paths.append(static_path)
	tracked_paths.sort()
	return tracked_paths

func collect_static_signature_paths() -> Array[String]:
	var tracked_paths: Array[String] = []
	var seen_paths: Dictionary = {}
	for raw_path in signature_static_file_paths:
		var path := String(raw_path).strip_edges()
		if path.is_empty() or seen_paths.has(path):
			continue
		seen_paths[path] = true
		tracked_paths.append(path)
	for raw_dir_path in signature_static_dir_paths:
		for path in collect_gd_paths_recursive(String(raw_dir_path).strip_edges()):
			if path.is_empty() or seen_paths.has(path):
				continue
			seen_paths[path] = true
			tracked_paths.append(path)
	tracked_paths.sort()
	return tracked_paths

func collect_gd_paths_recursive(dir_path: String) -> Array[String]:
	if dir_path.is_empty():
		return []
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return []
	var paths: Array[String] = []
	for raw_subdir_name in dir_access.get_directories():
		paths.append_array(collect_gd_paths_recursive("%s/%s" % [dir_path, String(raw_subdir_name)]))
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name).strip_edges()
		if file_name.get_extension() != "gd":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	return paths

func collect_signature_dependency_paths(path: String) -> Array[String]:
	if not path.begins_with("res://") and not path.begins_with("user://"):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var dependency_paths: Array[String] = []
	for raw_line in file.get_as_text().split("\n"):
		var line := String(raw_line).strip_edges()
		if not line.begins_with("[ext_resource"):
			continue
		var dependency_path := extract_dependency_path(line)
		if not should_track_dependency_path(dependency_path):
			continue
		dependency_paths.append(dependency_path)
	return dependency_paths

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
