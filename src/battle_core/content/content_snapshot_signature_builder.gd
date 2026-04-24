extends RefCounted
class_name ContentSnapshotSignatureBuilder

var dependency_collector = null
var last_error_message := ""

func build_signature(content_snapshot_paths: PackedStringArray) -> String:
	last_error_message = ""
	if dependency_collector == null:
		last_error_message = "ContentSnapshotSignatureBuilder requires dependency_collector"
		return ""
	var tracked_paths: Array[String] = dependency_collector.collect_tracked_signature_paths(content_snapshot_paths)
	if tracked_paths.is_empty():
		last_error_message = String(dependency_collector.get("last_error_message"))
		if last_error_message.is_empty():
			last_error_message = "ContentSnapshotSignatureBuilder requires tracked signature paths"
		return ""
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	var signature_parts: Array[String] = []
	for path in tracked_paths:
		signature_parts.append(path)
		var sha256 := _read_file_sha256(path)
		if not sha256.is_empty():
			signature_parts.append("sha256:%s" % sha256)
			continue
		last_error_message = "ContentSnapshotSignatureBuilder failed to hash tracked path: %s" % path
		return ""
	hashing_context.update("\n".join(signature_parts).to_utf8_buffer())
	return hashing_context.finish().hex_encode()

func _read_file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hashing_context = HashingContext.new()
	hashing_context.start(HashingContext.HASH_SHA256)
	hashing_context.update(file.get_buffer(file.get_length()))
	return hashing_context.finish().hex_encode()
