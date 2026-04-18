extends RefCounted
class_name FormalCharacterManifestLoader

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

const DEFAULT_MANIFEST_PATH := "res://config/formal_character_manifest.json"
const CHARACTERS_BUCKET := "characters"
const MATCHUPS_BUCKET := "matchups"

func load_manifest_payload_result(manifest_path: String, manifest_path_override: String = "") -> Dictionary:
	var resolved_manifest_path := resolve_manifest_path(manifest_path, manifest_path_override)
	var file := FileAccess.open(resolved_manifest_path, FileAccess.READ)
	if file == null:
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest missing manifest: %s" % resolved_manifest_path
		)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest expects top-level dictionary: %s" % resolved_manifest_path
		)
	if parsed.has("pair_surface_cases"):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest no longer accepts pair_surface_cases: %s" % resolved_manifest_path
		)
	var characters = parsed.get(CHARACTERS_BUCKET, null)
	if not (characters is Array):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest[%s] must be array: %s" % [CHARACTERS_BUCKET, resolved_manifest_path]
		)
	var matchups = parsed.get(MATCHUPS_BUCKET, null)
	if not (matchups is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest[%s] must be dictionary: %s" % [MATCHUPS_BUCKET, resolved_manifest_path]
		)
	if parsed.has("pair_interaction_cases"):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest no longer accepts pair_interaction_cases: %s" % resolved_manifest_path
		)
	if parsed.has("pair_interaction_specs"):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest no longer accepts pair_interaction_specs: %s" % resolved_manifest_path
		)
	return _ok_result({
		CHARACTERS_BUCKET: characters.duplicate(true),
		MATCHUPS_BUCKET: matchups.duplicate(true),
	})

func resolve_manifest_path(manifest_path: String, manifest_path_override: String = "") -> String:
	var normalized_path := normalize_resource_path(manifest_path)
	if not normalized_path.is_empty():
		return normalized_path
	return normalize_resource_path(manifest_path_override) if not String(manifest_path_override).strip_edges().is_empty() else DEFAULT_MANIFEST_PATH

static func normalize_resource_path(raw_path: String) -> String:
	var trimmed_path := String(raw_path).strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

func _ok_result(data) -> Dictionary:
	return ResultEnvelopeHelperScript.ok(data)

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)
