extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const GojoValidatorScript := preload("res://src/battle_core/content/formal_validators/gojo/content_snapshot_formal_gojo_validator.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")


func test_formal_character_validator_registry_runtime_contract() -> void:
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries()
	if not bool(load_result.get("ok", false)):
		fail("formal character validator registry should load cleanly: %s" % String(load_result.get("error_message", "")))
		return
	var entries: Array = load_result.get("data", [])
	if entries.is_empty():
		fail("formal character validator registry should expose at least one manifest entry")
		return
	var descriptor_result: Dictionary = FormalCharacterValidatorRegistryScript.build_validator_descriptors()
	if not bool(descriptor_result.get("ok", false)):
		fail("formal character validator descriptors should build cleanly: %s" % String(descriptor_result.get("error_message", "")))
		return
	var descriptors: Array = descriptor_result.get("data", [])
	if descriptors.size() != entries.size():
		fail("formal character validator descriptors should match manifest entry count")
		return
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			fail("formal character validator descriptor must be Dictionary")
			return
		var descriptor: Dictionary = raw_descriptor
		if String(descriptor.get("character_id", "")).is_empty():
			fail("formal character validator descriptor missing character_id")
			return
		if String(descriptor.get("unit_definition_id", "")).is_empty():
			fail("formal character validator descriptor missing unit_definition_id")
			return
		if String(descriptor.get("content_validator_script_path", "")).is_empty():
			fail("formal character validator descriptor missing content_validator_script_path")
			return
		var instantiate_result: Dictionary = FormalCharacterValidatorRegistryScript.instantiate_validator_descriptor(descriptor)
		if not bool(instantiate_result.get("ok", false)):
			fail("formal character validator descriptor should still instantiate when present: %s" % String(instantiate_result.get("error_message", "")))
			return
		var validator = instantiate_result.get("data", null)
		if validator == null or not validator.has_method("validate"):
			fail("formal character validator registry returned invalid validator instance")
			return

func test_formal_character_baseline_manifest_id_contract() -> void:
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries()
	if not bool(load_result.get("ok", false)):
		fail("formal character validator registry should load cleanly for baseline id contract: %s" % String(load_result.get("error_message", "")))
		return
	var expected_ids := PackedStringArray()
	for raw_entry in load_result.get("data", []):
		var entry: Dictionary = raw_entry
		expected_ids.append(String(entry.get("character_id", "")).strip_edges())
	if FormalCharacterBaselinesScript.character_ids() != expected_ids:
		fail("formal character baselines must expose manifest-order official ids only")
		return

func test_formal_character_baseline_descriptor_error_contract() -> void:
	var helper = ContractHelperScript.new()
	var validator = GojoValidatorScript.new()
	var errors: Array = []
	helper.validate_unit_contract_descriptor(
		validator,
		null,
		errors,
		FormalCharacterBaselinesScript.unit_contract("missing_formal_character")
	)
	helper.validate_skill_contracts(
		validator,
		null,
		errors,
		[FormalCharacterBaselinesScript.skill_contract("gojo_satoru", "missing_gojo_skill")]
	)
	if errors.size() != 2:
		fail("baseline descriptor errors should surface as structured validation errors, got: %s" % var_to_str(errors))
		return
	if String(errors[0]).find("unknown character_id") == -1:
		fail("missing baseline script error should stay structured, got: %s" % String(errors[0]))
		return
	if String(errors[1]).find("missing skill descriptor") == -1:
		fail("missing skill descriptor error should stay structured, got: %s" % String(errors[1]))
		return

func test_formal_character_runtime_registry_duplicate_unit_definition_guard_contract() -> void:
	var manifest_path := "user://formal_character_manifest_duplicate_unit_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"]
		),
		_build_runtime_registry_entry(
			"sukuna_alias",
			"gojo_satoru",
			"sukuna_setup",
			["content/units/sukuna/sukuna.tres"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		fail("failed to write duplicate manifest fixture")
		return
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
	var error_message := String(load_result.get("error_message", ""))
	if error_message.find("duplicated unit_definition_id") == -1:
		fail("runtime registry should fail fast on duplicated unit_definition_id")
		return

func test_formal_character_runtime_registry_duplicate_setup_matchup_guard_contract() -> void:
	var manifest_path := "user://formal_character_manifest_duplicate_setup_matchup_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"gojoalias"
		),
		_build_runtime_registry_entry(
			"sukuna_alias",
			"sukuna",
			"gojo_vs_sample",
			["content/units/sukuna/sukuna.tres"],
			"",
			"sukunaalias"
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		fail("failed to write duplicate setup matchup manifest fixture")
		return
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
	var error_message := String(load_result.get("error_message", ""))
	if error_message.find("duplicated formal_setup_matchup_id") == -1:
		fail("runtime registry should fail fast on duplicated formal_setup_matchup_id, got: %s" % error_message)
		return

func test_formal_character_runtime_registry_required_field_guard_contract() -> void:
	var bad_cases: Array = [
		{
			"missing_key": "unit_definition_id",
			"expected_error": "missing unit_definition_id",
		},
		{
			"missing_key": "formal_setup_matchup_id",
			"expected_error": "missing formal_setup_matchup_id",
		},
		{
			"missing_key": "pair_token",
			"expected_error": "missing pair_token",
		},
		{
			"missing_key": "baseline_script_path",
			"expected_error": "missing baseline_script_path",
		},
		{
			"missing_key": "required_content_paths",
			"expected_error": "missing required_content_paths",
		},
		{
			"missing_key": "owned_pair_interaction_specs",
			"expected_error": "missing owned_pair_interaction_specs",
		},
	]
	for raw_case in bad_cases:
		var bad_case: Dictionary = raw_case
		var missing_key := String(bad_case.get("missing_key", "")).strip_edges()
		var manifest_path := "user://formal_character_manifest_missing_field_%s_fixture.json" % missing_key
		var entry := _build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_alias_vs_sukuna_alias",
			["content/units/gojo/gojo_satoru.tres"]
		)
		entry.erase(missing_key)
		var manifest_payload := JSON.stringify(_build_manifest_payload([entry]), "  ")
		if not _write_json_fixture(manifest_path, manifest_payload):
			fail("failed to write missing-field manifest fixture")
			return
		var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
		var error_message := String(load_result.get("error_message", ""))
		var expected_error := String(bad_case.get("expected_error", ""))
		if error_message.find(expected_error) == -1:
			fail("formal manifest should fail fast on %s, got: %s" % [expected_error, error_message])
			return

func test_formal_character_runtime_registry_ignores_delivery_field_contract() -> void:
	var manifest_path := "user://formal_character_manifest_runtime_only_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		fail("failed to write runtime-only manifest fixture")
		return
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
	if not bool(load_result.get("ok", false)):
		fail("runtime registry should not depend on delivery-only fields: %s" % String(load_result.get("error_message", "")))
		return
	var entries: Array = load_result.get("data", [])
	if entries.size() != 1:
		fail("runtime registry should load runtime-only entry")
		return
	var entry: Dictionary = entries[0]
	if String(entry.get("character_id", "")) != "gojo_alias":
		fail("runtime registry should preserve character_id on runtime-only entry")
		return

func test_formal_character_runtime_registry_ignores_pair_interaction_catalog_contract() -> void:
	var manifest_path := "user://formal_character_manifest_runtime_pair_coverage_fixture.json"
	var characters := [
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"]
		),
		_build_runtime_registry_entry(
			"sukuna_alias",
			"sukuna",
			"sukuna_setup",
			["content/units/sukuna/sukuna.tres"]
		),
	]
	characters[1]["owned_pair_interaction_specs"] = []
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		characters[0],
		characters[1],
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		fail("failed to write runtime/pair-coverage manifest fixture")
		return
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
	if not bool(load_result.get("ok", false)):
		fail("runtime registry should ignore owned pair interaction coverage drift: %s" % String(load_result.get("error_message", "")))
		return
	var entries: Array = load_result.get("data", [])
	if entries.size() != 2:
		fail("runtime registry should still load runtime entries when owned pair interaction coverage drifts")
		return

func test_formal_character_runtime_registry_missing_validator_guard_contract() -> void:
	var manifest_path := "user://formal_character_manifest_missing_validator_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"src/battle_core/content/formal_validators/gojo/missing_validator.gd"
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		fail("failed to write missing-validator manifest fixture")
		return
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
	var error_message := String(load_result.get("error_message", ""))
	if error_message.find("missing validator") == -1 and error_message.find("failed to load validator") == -1:
		fail("formal manifest should fail fast on missing validator path")
		return

