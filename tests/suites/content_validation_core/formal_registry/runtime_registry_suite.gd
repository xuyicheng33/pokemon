extends "res://tests/suites/content_validation_core/formal_registry/shared.gd"

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_character_validator_registry_runtime_contract", failures, Callable(self, "_test_formal_character_validator_registry_runtime_contract").bind(harness))
	runner.run_test("formal_character_runtime_registry_duplicate_unit_definition_guard_contract", failures, Callable(self, "_test_formal_character_runtime_registry_duplicate_unit_definition_guard_contract").bind(harness))
	runner.run_test("formal_character_runtime_registry_required_field_guard_contract", failures, Callable(self, "_test_formal_character_runtime_registry_required_field_guard_contract").bind(harness))
	runner.run_test("formal_character_runtime_registry_missing_validator_guard_contract", failures, Callable(self, "_test_formal_character_runtime_registry_missing_validator_guard_contract").bind(harness))

func _test_formal_character_validator_registry_runtime_contract(harness) -> Dictionary:
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries()
	var error_message := String(load_result.get("error", ""))
	if not error_message.is_empty():
		return harness.fail_result("formal character validator registry should load cleanly: %s" % error_message)
	var entries: Array = load_result.get("entries", [])
	if entries.is_empty():
		return harness.fail_result("formal character validator registry should expose at least one manifest entry")
	var descriptor_result: Dictionary = FormalCharacterValidatorRegistryScript.build_validator_descriptors()
	error_message = String(descriptor_result.get("error", ""))
	if not error_message.is_empty():
		return harness.fail_result("formal character validator descriptors should build cleanly: %s" % error_message)
	var descriptors: Array = descriptor_result.get("descriptors", [])
	if descriptors.size() != entries.size():
		return harness.fail_result("formal character validator descriptors should match manifest entry count")
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			return harness.fail_result("formal character validator descriptor must be Dictionary")
		var descriptor: Dictionary = raw_descriptor
		if String(descriptor.get("character_id", "")).is_empty():
			return harness.fail_result("formal character validator descriptor missing character_id")
		if String(descriptor.get("unit_definition_id", "")).is_empty():
			return harness.fail_result("formal character validator descriptor missing unit_definition_id")
		if String(descriptor.get("content_validator_script_path", "")).is_empty():
			return harness.fail_result("formal character validator descriptor missing content_validator_script_path")
		var instantiate_result: Dictionary = FormalCharacterValidatorRegistryScript.instantiate_validator_descriptor(descriptor)
		error_message = String(instantiate_result.get("error", ""))
		if not error_message.is_empty():
			return harness.fail_result("formal character validator descriptor should still instantiate when present: %s" % error_message)
		var validator = instantiate_result.get("validator", null)
		if validator == null or not validator.has_method("validate"):
			return harness.fail_result("formal character validator registry returned invalid validator instance")
	return harness.pass_result()

func _test_formal_character_runtime_registry_duplicate_unit_definition_guard_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_duplicate_unit_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_manifest_character_entry(
			"gojo_alias",
			"Gojo Alias",
			"shared_unit",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"tests/suites/gojo_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
		_build_manifest_character_entry(
			"sukuna_alias",
			"Sukuna Alias",
			"shared_unit",
			"sukuna_setup",
			["content/units/sukuna/sukuna.tres"],
			"",
			"docs/design/sukuna_design.md",
			"docs/design/sukuna_adjustments.md",
			"sukuna_kai",
			"tests/suites/sukuna_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["sukuna_manager_smoke_contract"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write duplicate manifest fixture")
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
	var error_message := String(load_result.get("error", ""))
	if error_message.find("duplicated unit_definition_id") == -1:
		return harness.fail_result("runtime registry should fail fast on duplicated unit_definition_id")
	return harness.pass_result()

func _test_formal_character_runtime_registry_required_field_guard_contract(harness) -> Dictionary:
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
			"missing_key": "required_content_paths",
			"expected_error": "missing required_content_paths",
		},
	]
	for raw_case in bad_cases:
		var bad_case: Dictionary = raw_case
		var missing_key := String(bad_case.get("missing_key", "")).strip_edges()
		var manifest_path := "user://formal_character_manifest_missing_field_%s_fixture.json" % missing_key
		var entry := _build_manifest_character_entry(
			"gojo_alias",
			"Gojo Alias",
			"gojo_satoru",
			"gojo_alias_vs_sukuna_alias",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"tests/suites/gojo_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		)
		entry.erase(missing_key)
		var manifest_payload := JSON.stringify(_build_manifest_payload([entry]), "  ")
		if not _write_json_fixture(manifest_path, manifest_payload):
			return harness.fail_result("failed to write missing-field manifest fixture")
		var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
		var error_message := String(load_result.get("error", ""))
		var expected_error := String(bad_case.get("expected_error", ""))
		if error_message.find(expected_error) == -1:
			return harness.fail_result("formal manifest should fail fast on %s, got: %s" % [expected_error, error_message])
	return harness.pass_result()

func _test_formal_character_runtime_registry_missing_validator_guard_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_missing_validator_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_manifest_character_entry(
			"gojo_alias",
			"Gojo Alias",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"src/battle_core/content/formal_validators/gojo/missing_validator.gd",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"tests/suites/gojo_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write missing-validator manifest fixture")
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries_from_path(manifest_path)
	var error_message := String(load_result.get("error", ""))
	if error_message.find("missing validator") == -1 and error_message.find("failed to load validator") == -1:
		return harness.fail_result("formal manifest should fail fast on missing validator path")
	return harness.pass_result()
