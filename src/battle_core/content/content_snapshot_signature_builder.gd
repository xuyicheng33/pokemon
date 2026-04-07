extends RefCounted
class_name ContentSnapshotSignatureBuilder

var dependency_collector = null

func build_signature(content_snapshot_paths: PackedStringArray) -> String:
	if dependency_collector == null:
		return ""
	var tracked_paths: Array[String] = dependency_collector.collect_tracked_signature_paths(content_snapshot_paths)
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
