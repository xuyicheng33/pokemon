extends "res://tests/suites/content_validation_core/base.gd"

const FormalCharacterPairSmokeSharedScript := preload("res://tests/suites/formal_character_pair_smoke/shared.gd")
const FormalCharacterRegistryScript := preload("res://tests/support/formal_character_registry.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const ContentSnapshotFormalCharacterValidatorScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator.gd")
const InvalidValidatorFixturePath := "tests/fixtures/formal_validators/invalid_missing_validate_validator.gd"

func _write_json_fixture(path: String, payload: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	return true

func _setup_signature(battle_setup) -> Array:
	var signature: Array = []
	if battle_setup == null:
		return signature
	for side_setup in battle_setup.sides:
		signature.append({
			"side_id": String(side_setup.side_id),
			"unit_definition_ids": PackedStringArray(side_setup.unit_definition_ids),
			"starting_index": int(side_setup.starting_index),
		})
	return signature

func _build_runtime_registry_entry(character_id: String, unit_definition_id: String, matchup_id: String, required_content_paths: Array, validator_path: String = "") -> Dictionary:
	var entry := {
		"character_id": character_id,
		"unit_definition_id": unit_definition_id,
		"formal_setup_matchup_id": matchup_id,
		"required_content_paths": required_content_paths,
	}
	if not validator_path.is_empty():
		entry["content_validator_script_path"] = validator_path
	return entry

func _build_delivery_registry_entry(
	character_id: String,
	display_name: String,
	design_doc: String,
	adjustment_doc: String,
	surface_smoke_skill_id: String,
	suite_path: String,
	required_suite_paths: Array,
	required_test_names: Array,
	design_needles: Array,
	adjustment_needles: Array
) -> Dictionary:
	return {
		"character_id": character_id,
		"display_name": display_name,
		"design_doc": design_doc,
		"adjustment_doc": adjustment_doc,
		"surface_smoke_skill_id": surface_smoke_skill_id,
		"suite_path": suite_path,
		"required_suite_paths": required_suite_paths,
		"required_test_names": required_test_names,
		"design_needles": design_needles,
		"adjustment_needles": adjustment_needles,
	}
