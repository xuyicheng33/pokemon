extends RefCounted
class_name ResourcePathHelper

static func normalize(raw_path: String) -> String:
	var trimmed_path := String(raw_path).strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

static func resolve(raw_path: String, default_path: String) -> String:
	var normalized_path := normalize(raw_path)
	if normalized_path.is_empty():
		return default_path
	return normalized_path
