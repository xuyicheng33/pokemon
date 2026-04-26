extends RefCounted
class_name FormalCharacterCapabilityCatalog

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResourcePathHelperScript := preload("res://src/shared/resource_path_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

const DEFAULT_CATALOG_PATH := "res://config/formal_character_capability_catalog.json"
const CAPABILITIES_BUCKET := "capabilities"
const REQUIRED_STRING_FIELDS := ["capability_id", "stop_and_specialize_when"]
const REQUIRED_ARRAY_FIELDS := [
	"rule_doc_paths",
	"required_suite_paths",
	"required_fact_ids",
]

var catalog_path_override: String = ""
var _cached_entries_result_by_path: Dictionary = {}

func load_entries_result(catalog_path: String = "") -> Dictionary:
	var resolved_catalog_path := _resolve_catalog_path(catalog_path)
	if _cached_entries_result_by_path.has(resolved_catalog_path):
		return _cached_entries_result_by_path.get(resolved_catalog_path, {})
	var file := FileAccess.open(resolved_catalog_path, FileAccess.READ)
	if file == null:
		return _cache_entries_result(
			resolved_catalog_path,
			_error_result("FormalCharacterCapabilityCatalog missing catalog: %s" % resolved_catalog_path)
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _cache_entries_result(
			resolved_catalog_path,
			_error_result("FormalCharacterCapabilityCatalog expects top-level dictionary: %s" % resolved_catalog_path)
		)
	var raw_entries = parsed.get(CAPABILITIES_BUCKET, null)
	if not (raw_entries is Array):
		return _cache_entries_result(
			resolved_catalog_path,
			_error_result("FormalCharacterCapabilityCatalog[%s] must be array: %s" % [CAPABILITIES_BUCKET, resolved_catalog_path])
		)
	var seen_capability_ids: Dictionary = {}
	var entries: Array = []
	for entry_index in range(raw_entries.size()):
		var raw_entry = raw_entries[entry_index]
		if not (raw_entry is Dictionary):
			return _cache_entries_result(
				resolved_catalog_path,
				_error_result(
					"FormalCharacterCapabilityCatalog[%s][%d] must be dictionary: %s" % [
						CAPABILITIES_BUCKET,
						entry_index,
						resolved_catalog_path,
					]
				)
			)
		var entry: Dictionary = raw_entry
		for field_name in REQUIRED_STRING_FIELDS:
			if String(entry.get(field_name, "")).strip_edges().is_empty():
				return _cache_entries_result(
					resolved_catalog_path,
					_error_result("FormalCharacterCapabilityCatalog[%s][%d] missing %s" % [CAPABILITIES_BUCKET, entry_index, field_name])
				)
		for field_name in REQUIRED_ARRAY_FIELDS:
			var value = entry.get(field_name, null)
			if not (value is Array):
				return _cache_entries_result(
					resolved_catalog_path,
					_error_result("FormalCharacterCapabilityCatalog[%s][%d] missing %s" % [CAPABILITIES_BUCKET, entry_index, field_name])
				)
			if value.is_empty():
				return _cache_entries_result(
					resolved_catalog_path,
					_error_result("FormalCharacterCapabilityCatalog[%s][%d] empty %s" % [CAPABILITIES_BUCKET, entry_index, field_name])
				)
		var capability_id := String(entry.get("capability_id", "")).strip_edges()
		if seen_capability_ids.has(capability_id):
			return _cache_entries_result(
				resolved_catalog_path,
				_error_result("FormalCharacterCapabilityCatalog duplicated capability_id: %s" % capability_id)
			)
		seen_capability_ids[capability_id] = true
		entries.append(entry.duplicate(true))
	return _cache_entries_result(resolved_catalog_path, ResultEnvelopeHelperScript.ok(entries))

func find_entry_result(capability_id: String, catalog_path: String = "") -> Dictionary:
	var entries_result := load_entries_result(catalog_path)
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		if String(entry.get("capability_id", "")).strip_edges() == capability_id:
			return ResultEnvelopeHelperScript.ok(entry.duplicate(true))
	return _error_result("FormalCharacterCapabilityCatalog unknown capability_id: %s" % capability_id)

func capability_ids_result(catalog_path: String = "") -> Dictionary:
	var entries_result := load_entries_result(catalog_path)
	if not bool(entries_result.get("ok", false)):
		return entries_result
	var capability_ids := PackedStringArray()
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		capability_ids.append(String(entry.get("capability_id", "")).strip_edges())
	return ResultEnvelopeHelperScript.ok(capability_ids)

func _resolve_catalog_path(catalog_path: String) -> String:
	var normalized_path := ResourcePathHelperScript.normalize(catalog_path)
	if not normalized_path.is_empty():
		return normalized_path
	return ResourcePathHelperScript.resolve(catalog_path_override, DEFAULT_CATALOG_PATH)

func _error_result(error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_BATTLE_SETUP, error_message)

func _cache_entries_result(resolved_catalog_path: String, result: Dictionary) -> Dictionary:
	_cached_entries_result_by_path[resolved_catalog_path] = result
	return result
