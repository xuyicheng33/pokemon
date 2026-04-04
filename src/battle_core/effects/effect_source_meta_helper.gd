extends RefCounted
class_name EffectSourceMetaHelper

const SOURCE_OWNER_ID_KEY := "source_owner_id"

static func build_meta(source_owner_id: String, extra_meta: Dictionary = {}) -> Dictionary:
	var normalized_owner_id := String(source_owner_id).strip_edges()
	assert(not normalized_owner_id.is_empty(), "EffectSourceMetaHelper requires source_owner_id")
	var merged_meta := extra_meta.duplicate(true)
	merged_meta[SOURCE_OWNER_ID_KEY] = normalized_owner_id
	return merged_meta

static func require_source_owner_id(meta: Dictionary) -> String:
	var source_owner_id := resolve_source_owner_id(meta)
	assert(not source_owner_id.is_empty(), "EffectSourceMetaHelper missing source_owner_id")
	return source_owner_id

static func resolve_source_owner_id(meta: Dictionary) -> String:
	return String(meta.get(SOURCE_OWNER_ID_KEY, "")).strip_edges()
