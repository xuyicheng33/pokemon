extends RefCounted
class_name FormalCharacterManifestViews

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const FormalCharacterCapabilityCatalogScript := preload("res://src/shared/formal_character_capability_catalog.gd")
const ManifestLoaderScript := preload("res://src/shared/formal_character_manifest/formal_character_manifest_loader.gd")
const FormalRegistryContractsScript := preload("res://src/shared/formal_registry_contracts.gd")

const CHARACTERS_BUCKET := "characters"
const PAIR_INTERACTION_CASES_BUCKET := "pair_interaction_cases"
const VALIDATOR_REQUIRED_SUITE_PATH := "tests/suites/extension_validation_contract_suite.gd"

var _registry_contracts = FormalRegistryContractsScript.new()

func validate_runtime_characters_result(characters: Array, manifest_path: String) -> Dictionary:
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
			var resolved_validator_path := ManifestLoaderScript.normalize_resource_path(validator_path)
			if not ResourceLoader.exists(resolved_validator_path):
				return _error_result(
					ErrorCodesScript.INVALID_BATTLE_SETUP,
					"FormalCharacterManifest[%s] missing validator: %s" % [character_id, resolved_validator_path]
				)
			entry["content_validator_script_path"] = resolved_validator_path
		entries.append(entry.duplicate(true))
	return _ok_result(entries)

func build_runtime_entries_result(characters: Array) -> Dictionary:
	var runtime_entries: Array = []
	for raw_entry in characters:
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

func build_delivery_entries_result(characters: Array) -> Dictionary:
	var capability_suite_paths_result := _capability_suite_paths_by_id_result()
	if not bool(capability_suite_paths_result.get("ok", false)):
		return capability_suite_paths_result
	var capability_suite_paths_by_id: Dictionary = capability_suite_paths_result.get("data", {})
	var delivery_entries: Array = []
	for raw_entry in characters:
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		var field_result := _registry_contracts.validate_required_fields_result(
			FormalRegistryContractsScript.MANIFEST_CHARACTER_DELIVERY_BUCKET,
			entry,
			"FormalCharacterManifest[%s][%s]" % [CHARACTERS_BUCKET, character_id]
		)
		if not bool(field_result.get("ok", false)):
			return field_result
		var required_suite_paths_result := _effective_required_suite_paths_result(
			entry,
			capability_suite_paths_by_id
		)
		if not bool(required_suite_paths_result.get("ok", false)):
			return required_suite_paths_result
		delivery_entries.append({
			"character_id": character_id,
			"display_name": String(entry.get("display_name", "")).strip_edges(),
			"design_doc": String(entry.get("design_doc", "")).strip_edges(),
			"adjustment_doc": String(entry.get("adjustment_doc", "")).strip_edges(),
			"surface_smoke_skill_id": String(entry.get("surface_smoke_skill_id", "")).strip_edges(),
			"suite_path": String(entry.get("suite_path", "")).strip_edges(),
			"required_suite_paths": required_suite_paths_result.get("data", []).duplicate(true),
			"required_test_names": entry.get("required_test_names", []).duplicate(true),
			"shared_capability_ids": entry.get("shared_capability_ids", []).duplicate(true),
			"design_needles": entry.get("design_needles", []).duplicate(true),
			"adjustment_needles": entry.get("adjustment_needles", []).duplicate(true),
		})
	return _ok_result(delivery_entries)

func validate_pair_interaction_cases_result(pair_interaction_cases: Array, manifest_path: String) -> Dictionary:
	var normalized_cases: Array = []
	for case_index in range(pair_interaction_cases.size()):
		var raw_case = pair_interaction_cases[case_index]
		if not (raw_case is Dictionary):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"FormalCharacterManifest[%s][%d] must be dictionary: %s" % [PAIR_INTERACTION_CASES_BUCKET, case_index, manifest_path]
			)
		var case_spec: Dictionary = raw_case.duplicate(true)
		var field_result := _registry_contracts.validate_required_fields_result(
			FormalRegistryContractsScript.PAIR_INTERACTION_CASE_BUCKET,
			case_spec,
			"FormalCharacterManifest[%s][%d]" % [PAIR_INTERACTION_CASES_BUCKET, case_index]
		)
		if not bool(field_result.get("ok", false)):
			return field_result
		normalized_cases.append(case_spec)
	return _ok_result(normalized_cases)

func _capability_suite_paths_by_id_result() -> Dictionary:
	var catalog = FormalCharacterCapabilityCatalogScript.new()
	var entries_result := catalog.load_entries_result()
	if not bool(entries_result.get("ok", false)):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			String(entries_result.get("error_message", "unknown capability catalog error"))
		)
	var suite_paths_by_id: Dictionary = {}
	for raw_entry in entries_result.get("data", []):
		var entry: Dictionary = raw_entry
		suite_paths_by_id[String(entry.get("capability_id", "")).strip_edges()] = entry.get("required_suite_paths", []).duplicate(true)
	return _ok_result(suite_paths_by_id)

func _effective_required_suite_paths_result(entry: Dictionary, capability_suite_paths_by_id: Dictionary) -> Dictionary:
	var required_suite_paths: Array = []
	var seen_suite_paths: Dictionary = {}
	for raw_suite_path in entry.get("required_suite_paths", []):
		_append_unique_suite_path(required_suite_paths, seen_suite_paths, String(raw_suite_path))
	for raw_capability_id in entry.get("shared_capability_ids", []):
		var capability_id := String(raw_capability_id).strip_edges()
		if capability_id.is_empty():
			continue
		if not capability_suite_paths_by_id.has(capability_id):
			return _error_result(
				ErrorCodesScript.INVALID_BATTLE_SETUP,
				"FormalCharacterManifest[%s] unknown shared_capability_id: %s" % [
					String(entry.get("character_id", "")).strip_edges(),
					capability_id,
				]
			)
		for raw_suite_path in capability_suite_paths_by_id.get(capability_id, []):
			_append_unique_suite_path(required_suite_paths, seen_suite_paths, String(raw_suite_path))
	var validator_path := String(entry.get("content_validator_script_path", "")).strip_edges()
	if not validator_path.is_empty():
		_append_unique_suite_path(required_suite_paths, seen_suite_paths, VALIDATOR_REQUIRED_SUITE_PATH)
	return _ok_result(required_suite_paths)

func _append_unique_suite_path(required_suite_paths: Array, seen_suite_paths: Dictionary, raw_suite_path: String) -> void:
	var suite_path := raw_suite_path.strip_edges()
	if suite_path.is_empty() or seen_suite_paths.has(suite_path):
		return
	seen_suite_paths[suite_path] = true
	required_suite_paths.append(suite_path)

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
