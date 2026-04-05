extends RefCounted
class_name ContentSnapshotCache

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _entries: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0
var _last_cache_hit: bool = false

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
    var normalized_paths: Array[String] = []
    for raw_path in content_snapshot_paths:
        normalized_paths.append(String(raw_path).strip_edges())
    normalized_paths.sort()
    if normalized_paths.is_empty():
        return ""
    var hashing_context = HashingContext.new()
    hashing_context.start(HashingContext.HASH_SHA256)
    var signature_parts: Array[String] = []
    for path in normalized_paths:
        signature_parts.append(path)
        var md5 := FileAccess.get_md5(path)
        if not md5.is_empty():
            signature_parts.append("md5:%s" % md5)
            continue
        signature_parts.append("mtime:%d" % FileAccess.get_modified_time(path))
    hashing_context.update("\n".join(signature_parts).to_utf8_buffer())
    return hashing_context.finish().hex_encode()
