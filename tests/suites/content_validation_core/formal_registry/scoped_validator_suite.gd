extends "res://tests/suites/content_validation_core/formal_registry/shared.gd"

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_character_validator_partial_snapshot_contract", failures, Callable(self, "_test_formal_character_validator_partial_snapshot_contract").bind(harness))
	runner.run_test("formal_character_validator_present_character_scope_contract", failures, Callable(self, "_test_formal_character_validator_present_character_scope_contract").bind(harness))
	runner.run_test("formal_character_validator_absent_bad_validator_ignored_contract", failures, Callable(self, "_test_formal_character_validator_absent_bad_validator_ignored_contract").bind(harness))
	runner.run_test("formal_character_validator_present_bad_validator_fail_fast_contract", failures, Callable(self, "_test_formal_character_validator_present_bad_validator_fail_fast_contract").bind(harness))

func _test_formal_character_validator_partial_snapshot_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var sample_only_content = BattleContentIndexScript.new()
	var sample_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/gojo/", "/sukuna/", "/kashimo/", "/obito/"]))
	if sample_only_paths is Dictionary and sample_only_paths.has("error"):
		return harness.fail_result(str(sample_only_paths.get("error", "sample-only snapshot path build failed")))
	if not sample_only_content.load_snapshot(sample_only_paths):
		return harness.fail_result("sample-only snapshot should validate without formal character assets: %s" % sample_only_content.last_error_message)
	var gojo_only_content = BattleContentIndexScript.new()
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
	if not gojo_only_content.load_snapshot(gojo_only_paths):
		return harness.fail_result("gojo-only snapshot should validate without unrelated formal characters: %s" % gojo_only_content.last_error_message)
	if not gojo_only_content.units.has("gojo_satoru") or gojo_only_content.units.has("sukuna") or gojo_only_content.units.has("kashimo_hajime") or gojo_only_content.units.has("obito_juubi_jinchuriki"):
		return harness.fail_result("gojo-only snapshot filter should keep only Gojo formal assets")
	return harness.pass_result()

func _test_formal_character_validator_present_character_scope_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = BattleContentIndexScript.new()
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
	if not content_index.load_snapshot(gojo_only_paths):
		return harness.fail_result("gojo-only snapshot should load before scoped validation probe: %s" % content_index.last_error_message)
	var burst_effect = content_index.effects.get("gojo_murasaki_conditional_burst", null)
	if burst_effect == null:
		return harness.fail_result("gojo-only snapshot missing gojo_murasaki_conditional_burst")
	burst_effect.required_target_same_owner = false
	var errors: Array = content_index.validate_snapshot()
	var saw_gojo_scope_error := false
	for error_msg in errors:
		var msg := str(error_msg)
		if msg.find("formal[gojo].murasaki_burst required_target_same_owner must be true") != -1:
			saw_gojo_scope_error = true
		if msg.find("formal[sukuna]") != -1 or msg.find("formal[kashimo]") != -1:
			return harness.fail_result("scoped formal validator should not report unrelated characters when only Gojo is loaded")
	if not saw_gojo_scope_error:
		return harness.fail_result("scoped formal validator should still enforce Gojo contracts when Gojo is present")
	return harness.pass_result()

func _test_formal_character_validator_absent_bad_validator_ignored_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var runtime_registry_path := "user://formal_character_runtime_registry_absent_bad_validator_fixture.json"
	var runtime_registry_payload := JSON.stringify([
		_build_runtime_registry_entry(
			"gojo_satoru",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"src/battle_core/content/formal_validators/gojo/content_snapshot_formal_gojo_validator.gd"
		),
		_build_runtime_registry_entry(
			"sukuna",
			"sukuna",
			"sukuna_setup",
			["content/units/sukuna/sukuna.tres"],
			InvalidValidatorFixturePath
		),
	], "  ")
	if not _write_json_fixture(runtime_registry_path, runtime_registry_payload):
		return harness.fail_result("failed to write absent-bad-validator runtime registry fixture")
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(gojo_only_paths):
		return harness.fail_result("gojo-only snapshot should load for absent-bad-validator contract: %s" % content_index.last_error_message)
	var validator = ContentSnapshotFormalCharacterValidatorScript.new()
	validator.registry_path_override = runtime_registry_path
	var errors: Array = []
	validator.validate(content_index, errors)
	if not errors.is_empty():
		return harness.fail_result("absent formal character bad validator should not affect current snapshot: %s" % "\n".join(errors))
	return harness.pass_result()

func _test_formal_character_validator_present_bad_validator_fail_fast_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var runtime_registry_path := "user://formal_character_runtime_registry_present_bad_validator_fixture.json"
	var runtime_registry_payload := JSON.stringify([
		_build_runtime_registry_entry(
			"gojo_satoru",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			InvalidValidatorFixturePath
		),
	], "  ")
	if not _write_json_fixture(runtime_registry_path, runtime_registry_payload):
		return harness.fail_result("failed to write present-bad-validator runtime registry fixture")
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(gojo_only_paths):
		return harness.fail_result("gojo-only snapshot should load for present-bad-validator contract: %s" % content_index.last_error_message)
	var validator = ContentSnapshotFormalCharacterValidatorScript.new()
	validator.registry_path_override = runtime_registry_path
	var errors: Array = []
	validator.validate(content_index, errors)
	if errors.is_empty():
		return harness.fail_result("present formal character bad validator should fail-fast during scoped validation")
	for raw_error in errors:
		if String(raw_error).find("failed to instantiate validator") != -1:
			return harness.pass_result()
	return harness.fail_result("present formal character bad validator should report instantiation failure")
