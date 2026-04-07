extends RefCounted
class_name FormalCharacterManifest

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalRegistryContractsScript := preload("res://src/shared/formal_registry_contracts.gd")

const DEFAULT_MANIFEST_PATH := "res://config/formal_character_manifest.json"
const CHARACTERS_BUCKET := "characters"
const MATCHUPS_BUCKET := "matchups"
const PAIR_INTERACTION_CASES_BUCKET := "pair_interaction_cases"

var manifest_path_override: String = ""
var _registry_contracts = FormalRegistryContractsScript.new()

func load_manifest_result(manifest_path: String = "") -> Dictionary:
	var resolved_manifest_path := _resolve_manifest_path(manifest_path)
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
	var pair_interaction_cases = parsed.get(PAIR_INTERACTION_CASES_BUCKET, null)
	if not (pair_interaction_cases is Array):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"FormalCharacterManifest[%s] must be array: %s" % [PAIR_INTERACTION_CASES_BUCKET, resolved_manifest_path]
		)
	var characters_result := _validate_runtime_characters_result(characters, resolved_manifest_path)
	if not bool(characters_result.get("ok", false)):
		return characters_result
	return _ok_result({
		CHARACTERS_BUCKET: characters_result.get("data", []).duplicate(true),
		MATCHUPS_BUCKET: matchups.duplicate(true),
		PAIR_INTERACTION_CASES_BUCKET: pair_interaction_cases.duplicate(true),
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
	var runtime_entries: Array = []
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		var runtime_entry := {
			"character_id": String(entry.get("character_id", "")).strip_edges(),
			"unit_definition_id": String(entry.get("unit_definition_id", "")).strip_edges(),
			"formal_setup_matchup_id": String(entry.get("formal_setup_matchup_id", "")).strip_edges(),
			"required_content_paths": entry.get("required_content_paths", []).duplicate(true),
		}
		var validator_path := String(entry.get("content_validator_script_path", "")).strip_edges()
		if not validator_path.is_empty():
			runtime_entry["content_validator_script_path"] = validator_path
		runtime_entries.append(runtime_entry)
	return _ok_result(runtime_entries)

func build_delivery_entries_result(manifest_path: String = "") -> Dictionary:
	var entries_result := build_character_entries_result(manifest_path)
	if not bool(entries_result.get("ok", false)):
		return entries_result
	var delivery_entries: Array = []
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var field_result := _registry_contracts.validate_required_fields_result(
			FormalRegistryContractsScript.MANIFEST_CHARACTER_DELIVERY_BUCKET,
			entry,
			"FormalCharacterManifest[%s][%s]" % [CHARACTERS_BUCKET, character_id]
		)
		if not bool(field_result.get("ok", false)):
			return field_result
		delivery_entries.append({
			"character_id": character_id,
			"display_name": String(entry.get("display_name", "")).strip_edges(),
			"design_doc": String(entry.get("design_doc", "")).strip_edges(),
			"adjustment_doc": String(entry.get("adjustment_doc", "")).strip_edges(),
			"surface_smoke_skill_id": String(entry.get("surface_smoke_skill_id", "")).strip_edges(),
			"suite_path": String(entry.get("suite_path", "")).strip_edges(),
			"required_suite_paths": entry.get("required_suite_paths", []).duplicate(true),
			"required_test_names": entry.get("required_test_names", []).duplicate(true),
			"design_needles": entry.get("design_needles", []).duplicate(true),
			"adjustment_needles": entry.get("adjustment_needles", []).duplicate(true),
		})
	return _ok_result(delivery_entries)

func build_catalog_result(manifest_path: String = "") -> Dictionary:
	var manifest_result := load_manifest_result(manifest_path)
	if not bool(manifest_result.get("ok", false)):
		return manifest_result
	var manifest: Dictionary = manifest_result.get("data", {})
	return _ok_result({
		"matchups": manifest.get(MATCHUPS_BUCKET, {}).duplicate(true),
		"pair_interaction_cases": manifest.get(PAIR_INTERACTION_CASES_BUCKET, []).duplicate(true),
	})

func _validate_runtime_characters_result(characters: Array, manifest_path: String) -> Dictionary:
	var seen_character_ids: Dictionary = {}
	var seen_unit_definition_ids: Dictionary = {}
	var entries: Array = []
	for entry_index in range(characters.size()):
		var raw_entry = characters[entry_index]
		if not (raw_entry is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"FormalCharacterManifest[%s][%d] must be dictionary: %s" % [CHARACTERS_BUCKET, entry_index, manifest_path]
			)
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var field_result := _registry_contracts.validate_required_fields_result(
			FormalRegistryContractsScript.MANIFEST_CHARACTER_RUNTIME_BUCKET,
			entry,
			"FormalCharacterManifest[%s][%s]" % [CHARACTERS_BUCKET, character_id if not character_id.is_empty() else str(entry_index)]
		)
		if not bool(field_result.get("ok", false)):
			return field_result
		if seen_character_ids.has(character_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"FormalCharacterManifest duplicated character_id: %s" % character_id
			)
		seen_character_ids[character_id] = true
		var unit_definition_id := String(entry.get("unit_definition_id", "")).strip_edges()
		if seen_unit_definition_ids.has(unit_definition_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"FormalCharacterManifest duplicated unit_definition_id: %s" % unit_definition_id
			)
		seen_unit_definition_ids[unit_definition_id] = true
		for raw_rel_path in entry.get("required_content_paths", []):
			if String(raw_rel_path).strip_edges().is_empty():
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"FormalCharacterManifest[%s] has empty required_content_paths entry" % character_id
				)
		var validator_path := String(entry.get("content_validator_script_path", "")).strip_edges()
		if not validator_path.is_empty():
			var resolved_validator_path := _normalize_resource_path(validator_path)
			if not ResourceLoader.exists(resolved_validator_path):
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"FormalCharacterManifest[%s] missing validator: %s" % [character_id, resolved_validator_path]
				)
			entry["content_validator_script_path"] = resolved_validator_path
		entries.append(entry.duplicate(true))
	return _ok_result(entries)

func _resolve_manifest_path(manifest_path: String) -> String:
	var normalized_path := _normalize_resource_path(manifest_path)
	if not normalized_path.is_empty():
		return normalized_path
	return _normalize_resource_path(manifest_path_override) if not String(manifest_path_override).strip_edges().is_empty() else DEFAULT_MANIFEST_PATH

func _normalize_resource_path(raw_path: String) -> String:
	var trimmed_path := String(raw_path).strip_edges()
	if trimmed_path.is_empty():
		return ""
	return trimmed_path if trimmed_path.begins_with("res://") or trimmed_path.begins_with("user://") else "res://%s" % trimmed_path

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
