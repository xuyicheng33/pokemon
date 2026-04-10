extends RefCounted
class_name FormalCharacterManifest

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ManifestLoaderScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_loader.gd")
const ManifestViewsScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_views.gd")

const CHARACTERS_BUCKET := "characters"
const MATCHUPS_BUCKET := "matchups"
const PAIR_INTERACTION_CASES_BUCKET := "pair_interaction_cases"

var manifest_path_override: String = ""
var _manifest_loader = ManifestLoaderScript.new()
var _manifest_views = ManifestViewsScript.new()

func load_manifest_result(manifest_path: String = "") -> Dictionary:
	var manifest_result := _manifest_loader.load_manifest_payload_result(manifest_path, manifest_path_override)
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var manifest: Dictionary = manifest_result.get("data", {})
	var resolved_manifest_path := _manifest_loader.resolve_manifest_path(manifest_path, manifest_path_override)
	var characters_result := _manifest_views.validate_runtime_characters_result(
		manifest.get(CHARACTERS_BUCKET, []),
		resolved_manifest_path
	)
	if not bool(characters_result.get("ok", false)):
		return characters_result
	return _ok_result({
		CHARACTERS_BUCKET: characters_result.get("data", []).duplicate(true),
		MATCHUPS_BUCKET: manifest.get(MATCHUPS_BUCKET, {}).duplicate(true),
		PAIR_INTERACTION_CASES_BUCKET: manifest.get(PAIR_INTERACTION_CASES_BUCKET, []).duplicate(true),
	})

func build_character_entries_result(manifest_path: String = "") -> Dictionary:
	var manifest_result := load_manifest_result(manifest_path)
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	return _ok_result(manifest_result.get("data", {}).get(CHARACTERS_BUCKET, []).duplicate(true))

func find_character_entry_result(character_id: String, manifest_path: String = "") -> Dictionary:
	var entries_result := build_character_entries_result(manifest_path)
	if not bool(entries_result.get("ok", false)):
		return entries_result
	for raw_entry in entries_result.get("data", []):
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if String(entry.get("character_id", "")).strip_edges() == character_id:
			return _ok_result(entry.duplicate(true))
	return _error_result(
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		"FormalCharacterManifest unknown character_id: %s" % character_id
	)

func build_runtime_entries_result(manifest_path: String = "") -> Dictionary:
	var entries_result := build_character_entries_result(manifest_path)
	if not bool(entries_result.get("ok", false)):
		return entries_result
	return _manifest_views.build_runtime_entries_result(entries_result.get("data", []))

func build_delivery_entries_result(manifest_path: String = "") -> Dictionary:
	var entries_result := build_character_entries_result(manifest_path)
	if not bool(entries_result.get("ok", false)):
		return entries_result
	return _manifest_views.build_delivery_entries_result(entries_result.get("data", []))

func build_catalog_result(manifest_path: String = "") -> Dictionary:
	var manifest_result := _manifest_loader.load_manifest_payload_result(manifest_path, manifest_path_override)
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var manifest: Dictionary = manifest_result.get("data", {})
	var pair_cases_result := _manifest_views.validate_pair_interaction_cases_result(
		manifest.get(PAIR_INTERACTION_CASES_BUCKET, []),
		_manifest_loader.resolve_manifest_path(manifest_path, manifest_path_override)
	)
	if not bool(pair_cases_result.get("ok", false)):
		return pair_cases_result
	return _ok_result({
		"matchups": manifest.get(MATCHUPS_BUCKET, {}).duplicate(true),
		"pair_interaction_cases": pair_cases_result.get("data", []).duplicate(true),
	})

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
