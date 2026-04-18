extends RefCounted
class_name FormalCharacterBaselineLoader

const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

static func character_ids() -> PackedStringArray:
	var resolved_ids := PackedStringArray()
	var entries_result := character_entries_result()
	if not bool(entries_result.get("ok", false)):
		return resolved_ids
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		resolved_ids.append(String(entry.get("character_id", "")).strip_edges())
	return resolved_ids

static func character_entries_result() -> Dictionary:
	var manifest = FormalCharacterManifestScript.new()
	var entries_result := manifest.build_runtime_entries_result()
	if not bool(entries_result.get("ok", false)):
		return _error_result(
			"FormalCharacterBaselines failed to load manifest entries: %s" % String(entries_result.get("error_message", "unknown error"))
		)
	return _ok_result(entries_result.get("data", []))

static func baseline_result(character_id: String, context: String = "") -> Dictionary:
	var normalized_id := character_id.strip_edges()
	var entry_result := _find_character_entry_result(normalized_id)
	if not bool(entry_result.get("ok", false)):
		return entry_result
	var entry: Dictionary = entry_result.get("data", {})
	var script_path := String(entry.get("baseline_script_path", "")).strip_edges()
	if script_path.is_empty():
		return _error_result("FormalCharacterBaselines[%s] missing baseline_script_path%s" % [normalized_id, _context_suffix(context)])
	if not ResourceLoader.exists(script_path):
		return _error_result(
			"FormalCharacterBaselines[%s] missing baseline script%s: %s" % [
				normalized_id,
				_context_suffix(context),
				script_path,
			]
		)
	var baseline_script = load(script_path)
	if not (baseline_script is Script) or not baseline_script.can_instantiate():
		return _error_result(
			"FormalCharacterBaselines[%s] baseline script is not instantiable%s: %s" % [
				normalized_id,
				_context_suffix(context),
				script_path,
			]
		)
	var baseline = baseline_script.new()
	if baseline == null:
		return _error_result(
			"FormalCharacterBaselines[%s] failed to instantiate baseline%s: %s" % [
				normalized_id,
				_context_suffix(context),
				script_path,
			]
		)
	return _ok_result(baseline)

static func _find_character_entry_result(character_id: String) -> Dictionary:
	var normalized_id := character_id.strip_edges()
	if normalized_id.is_empty():
		return _error_result("FormalCharacterBaselines lookup character_id must not be empty")
	var entries_result := character_entries_result()
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if String(entry.get("character_id", "")).strip_edges() == normalized_id:
			return _ok_result(entry.duplicate(true))
	return _error_result("FormalCharacterBaselines unknown character_id: %s" % normalized_id)

static func _context_suffix(context: String) -> String:
	return "" if context.strip_edges().is_empty() else " during %s" % context.strip_edges()

static func _ok_result(data) -> Dictionary:
	return ResultEnvelopeHelperScript.ok(data)

static func _error_result(error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(null, error_message.strip_edges())
