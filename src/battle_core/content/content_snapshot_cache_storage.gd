extends RefCounted
class_name ContentSnapshotCacheStorage

var _entries: Dictionary = {}
var _cache_hits: int = 0
var _cache_misses: int = 0
var _last_cache_hit: bool = false

func begin_request() -> void:
	_last_cache_hit = false

func load_resources(signature: String) -> Dictionary:
	var cached_resources: Array = _entries.get(signature, [])
	if cached_resources.is_empty():
		return {
			"found": false,
			"resources": [],
		}
	_cache_hits += 1
	_last_cache_hit = true
	return {
		"found": true,
		"resources": _duplicate_resources(cached_resources),
	}

func store_resources(signature: String, resources: Array) -> void:
	_entries[signature] = _duplicate_resources(resources)
	_cache_misses += 1
	_last_cache_hit = false

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

func _duplicate_resources(resources: Array) -> Array:
	var duplicates: Array = []
	for resource in resources:
		duplicates.append(resource.duplicate(true) if resource != null else null)
	return duplicates
