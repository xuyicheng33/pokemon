extends RefCounted
class_name ContentSnapshotCache

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _entries: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0
var _last_cache_hit: bool = false
var signature_static_file_paths := PackedStringArray([
	"res://config/formal_character_runtime_registry.json",
])
var signature_static_dir_paths := PackedStringArray([
	"res://src/battle_core/content",
	"res://src/battle_core/content/formal_validators",
])

func build_content_index(content_snapshot_paths: PackedStringArray) -> Dictionary:
	_last_cache_hit = false
	var signature := _build_signature(content_snapshot_paths)
	if signature.is_empty():
		return {
			"ok": false,
			"content_index": null,
			"cache_hit": false,
			"error_code": ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"error_message": "ContentSnapshotCache requires non-empty content_snapshot_paths",
		}
	var cached_resources: Array = _entries.get(signature, [])
	if not cached_resources.is_empty():
		_cache_hits += 1
		_last_cache_hit = true
		return _build_index_result(_duplicate_resources(cached_resources), false, true)
	var load_result: Dictionary = _load_validated_resources(content_snapshot_paths)
	if not bool(load_result.get("ok", false)):
		return load_result
	var validated_resources: Array = load_result.get("resources", [])
	_entries[signature] = validated_resources
	_cache_misses += 1
	return _build_index_result(_duplicate_resources(validated_resources), false, false)

func stats() -> Dictionary:
	return {
		"hits": _cache_hits,
		"misses": _cache_misses,
		"size": _entries.size(),
		"last_cache_hit": _last_cache_hit,
	}

func clear() -> void:
	_entries.clear()
	_cache_hits = 0
	_cache_misses = 0
	_last_cache_hit = false

func _load_validated_resources(content_snapshot_paths: PackedStringArray) -> Dictionary:
	var resources: Array = []
	for path in content_snapshot_paths:
		var resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			return {
				"ok": false,
				"content_index": null,
				"cache_hit": false,
				"error_code": ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
				"error_message": "Missing content resource: %s" % path,
			}
		resources.append(resource)
	return _build_index_result(resources, true, false, true)

func _build_index_result(resources: Array, run_validation: bool, cache_hit: bool, include_resources: bool = false) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_resources(resources, run_validation):
		var error_state: Dictionary = content_index.error_state()
		return {
			"ok": false,
			"content_index": null,
			"cache_hit": cache_hit,
			"error_code": error_state.get("code", ErrorCodesScript.INVALID_CONTENT_SNAPSHOT),
			"error_message": error_state.get("message", "ContentSnapshotCache failed to build content index"),
		}
	return {
		"ok": true,
		"content_index": content_index,
		"cache_hit": cache_hit,
		"resources": resources if include_resources else [],
		"error_code": null,
		"error_message": "",
	}

func _duplicate_resources(resources: Array) -> Array:
	var duplicates: Array = []
	for resource in resources:
		duplicates.append(resource.duplicate(true) if resource != null else null)
	return duplicates

func _build_signature(content_snapshot_paths: PackedStringArray) -> String:
	var tracked_paths := _collect_tracked_signature_paths(content_snapshot_paths)
	if tracked_paths.is_empty():
		return ""
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	var signature_parts: Array[String] = []
	for path in tracked_paths:
		signature_parts.append(path)
		var md5 := FileAccess.get_md5(path)
		if not md5.is_empty():
			signature_parts.append("md5:%s" % md5)
			continue
		signature_parts.append("mtime:%d" % FileAccess.get_modified_time(path))
	hashing_context.update("\n".join(signature_parts).to_utf8_buffer())
	return hashing_context.finish().hex_encode()

func _collect_tracked_signature_paths(content_snapshot_paths: PackedStringArray) -> Array[String]:
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
		for dependency_path in _collect_signature_dependency_paths(path):
			if not seen_paths.has(dependency_path):
				pending_paths.append(dependency_path)
	for static_path in _collect_static_signature_paths():
		if static_path.is_empty() or seen_paths.has(static_path):
			continue
		seen_paths[static_path] = true
		tracked_paths.append(static_path)
	tracked_paths.sort()
	return tracked_paths

func _collect_static_signature_paths() -> Array[String]:
	var tracked_paths: Array[String] = []
	var seen_paths: Dictionary = {}
	for raw_path in signature_static_file_paths:
		var path := String(raw_path).strip_edges()
		if path.is_empty() or seen_paths.has(path):
			continue
		seen_paths[path] = true
		tracked_paths.append(path)
	for raw_dir_path in signature_static_dir_paths:
		for path in _collect_gd_paths_recursive(String(raw_dir_path).strip_edges()):
			if path.is_empty() or seen_paths.has(path):
				continue
			seen_paths[path] = true
			tracked_paths.append(path)
	tracked_paths.sort()
	return tracked_paths

func _collect_gd_paths_recursive(dir_path: String) -> Array[String]:
	if dir_path.is_empty():
		return []
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return []
	var paths: Array[String] = []
	for raw_subdir_name in dir_access.get_directories():
		paths.append_array(_collect_gd_paths_recursive("%s/%s" % [dir_path, String(raw_subdir_name)]))
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name).strip_edges()
		if file_name.get_extension() != "gd":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	return paths

func _collect_signature_dependency_paths(path: String) -> Array[String]:
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
		var dependency_path := _extract_dependency_path(line)
		if not _should_track_dependency_path(dependency_path):
			continue
		dependency_paths.append(dependency_path)
	return dependency_paths

func _extract_dependency_path(ext_resource_line: String) -> String:
	var marker := 'path="'
	var start_index := ext_resource_line.find(marker)
	if start_index == -1:
		return ""
	start_index += marker.length()
	var end_index := ext_resource_line.find('"', start_index)
	if end_index == -1:
		return ""
	return ext_resource_line.substr(start_index, end_index - start_index).strip_edges()

func _should_track_dependency_path(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("res://content/"):
		return path.ends_with(".tres") or path.ends_with(".res")
	if path.begins_with("user://"):
		return true
	return false
