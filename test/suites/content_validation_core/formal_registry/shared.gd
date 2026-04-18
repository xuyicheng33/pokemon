extends "res://test/suites/content_validation_core/base.gd"

const FormalCharacterPairSmokeSharedScript := preload("res://test/suites/formal_character_pair_smoke/shared.gd")
const FormalCharacterRegistryScript := preload("res://tests/support/formal_character_registry.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const ContentSnapshotFormalCharacterValidatorScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator.gd")
const InvalidValidatorFixturePath := "tests/fixtures/formal_validators/invalid_missing_validate_validator.gd"
const DEFAULT_PAIR_INITIATOR_BENCH_UNIT_IDS := ["sample_mossaur", "sample_pyron"]
const DEFAULT_PAIR_RESPONDER_BENCH_UNIT_IDS := ["sample_tidekit", "sample_mossaur"]
const DEFAULT_VALIDATOR_PATH_BY_UNIT_ID := {
	"gojo_satoru": "src/battle_core/content/formal_validators/gojo/content_snapshot_formal_gojo_validator.gd",
	"sukuna": "src/battle_core/content/formal_validators/sukuna/content_snapshot_formal_sukuna_validator.gd",
	"kashimo_hajime": "src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_validator.gd",
	"obito_juubi_jinchuriki": "src/battle_core/content/formal_validators/obito/content_snapshot_formal_obito_validator.gd",
}

func _default_pair_token_for_matchup_id(matchup_id: String) -> String:
	var normalized_matchup_id := matchup_id.strip_edges()
	if normalized_matchup_id.ends_with("_vs_sample"):
		return normalized_matchup_id.left(normalized_matchup_id.length() - "_vs_sample".length())
	if normalized_matchup_id.ends_with("_setup"):
		return normalized_matchup_id.left(normalized_matchup_id.length() - "_setup".length())
	var infix_index := normalized_matchup_id.find("_vs_")
	if infix_index > 0:
		return normalized_matchup_id.substr(0, infix_index)
	return normalized_matchup_id

func _default_baseline_script_path_for_unit_id(unit_definition_id: String) -> String:
	var normalized_unit_definition_id := unit_definition_id.strip_edges()
	return "src/shared/formal_character_baselines/%s/%s_formal_character_baseline.gd" % [
		normalized_unit_definition_id,
		normalized_unit_definition_id,
	]

func _default_validator_script_path_for_unit_id(unit_definition_id: String) -> String:
	return String(DEFAULT_VALIDATOR_PATH_BY_UNIT_ID.get(unit_definition_id.strip_edges(), ""))

func _write_json_fixture(path: String, payload: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.flush()
	file.close()
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

func _build_runtime_registry_entry(
	character_id: String,
	unit_definition_id: String,
	matchup_id: String,
	required_content_paths: Array,
	validator_path: String = "",
	pair_token: String = "",
	baseline_script_path: String = "",
	owned_pair_interaction_specs: Array = []
) -> Dictionary:
	var entry := {
		"character_id": character_id,
		"unit_definition_id": unit_definition_id,
		"formal_setup_matchup_id": matchup_id,
		"pair_token": pair_token if not pair_token.strip_edges().is_empty() else _default_pair_token_for_matchup_id(matchup_id),
		"baseline_script_path": baseline_script_path if not baseline_script_path.strip_edges().is_empty() else _default_baseline_script_path_for_unit_id(unit_definition_id),
		"required_content_paths": required_content_paths,
		"pair_initiator_bench_unit_ids": DEFAULT_PAIR_INITIATOR_BENCH_UNIT_IDS.duplicate(),
		"pair_responder_bench_unit_ids": DEFAULT_PAIR_RESPONDER_BENCH_UNIT_IDS.duplicate(),
		"owned_pair_interaction_specs": owned_pair_interaction_specs.duplicate(true),
	}
	var resolved_validator_path := validator_path if not validator_path.is_empty() else _default_validator_script_path_for_unit_id(unit_definition_id)
	if not resolved_validator_path.is_empty():
		entry["content_validator_script_path"] = resolved_validator_path
	return entry

func _build_manifest_character_entry(
	character_id: String,
	display_name: String,
	unit_definition_id: String,
	matchup_id: String,
	required_content_paths: Array,
	validator_path: String,
	design_doc: String,
	adjustment_doc: String,
	surface_smoke_skill_id: String,
	suite_path: String,
	required_suite_paths: Array,
	required_test_names: Array,
	design_needles: Array,
	adjustment_needles: Array,
	shared_capability_ids: Array = [],
	pair_token: String = "",
	baseline_script_path: String = "",
	owned_pair_interaction_specs: Array = []
) -> Dictionary:
	var entry := {
		"character_id": character_id,
		"display_name": display_name,
		"unit_definition_id": unit_definition_id,
		"formal_setup_matchup_id": matchup_id,
		"pair_token": pair_token if not pair_token.strip_edges().is_empty() else _default_pair_token_for_matchup_id(matchup_id),
		"baseline_script_path": baseline_script_path if not baseline_script_path.strip_edges().is_empty() else _default_baseline_script_path_for_unit_id(unit_definition_id),
		"required_content_paths": required_content_paths,
		"pair_initiator_bench_unit_ids": DEFAULT_PAIR_INITIATOR_BENCH_UNIT_IDS.duplicate(),
		"pair_responder_bench_unit_ids": DEFAULT_PAIR_RESPONDER_BENCH_UNIT_IDS.duplicate(),
		"owned_pair_interaction_specs": owned_pair_interaction_specs.duplicate(true),
		"design_doc": design_doc,
		"adjustment_doc": adjustment_doc,
		"surface_smoke_skill_id": surface_smoke_skill_id,
		"suite_path": suite_path,
		"required_suite_paths": required_suite_paths,
		"required_test_names": required_test_names,
		"shared_capability_ids": shared_capability_ids,
		"design_needles": design_needles,
		"adjustment_needles": adjustment_needles,
	}
	var resolved_validator_path := validator_path if not validator_path.is_empty() else _default_validator_script_path_for_unit_id(unit_definition_id)
	if not resolved_validator_path.is_empty():
		entry["content_validator_script_path"] = resolved_validator_path
	return entry

func _build_owned_pair_interaction_spec(
	other_character_id: String,
	scenario_key: String,
	owner_as_initiator_battle_seed: int,
	owner_as_responder_battle_seed: int
) -> Dictionary:
	return {
		"other_character_id": other_character_id,
		"scenario_key": scenario_key,
		"owner_as_initiator_battle_seed": owner_as_initiator_battle_seed,
		"owner_as_responder_battle_seed": owner_as_responder_battle_seed,
	}

func _build_manifest_payload(characters: Array, matchups: Dictionary = {}) -> Dictionary:
	return {
		"characters": characters,
		"matchups": matchups,
	}
