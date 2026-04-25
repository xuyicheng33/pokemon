extends "res://test/suites/content_validation_core/formal_registry/shared.gd"



func test_formal_character_validator_partial_snapshot_contract() -> void:
	_assert_legacy_result(_test_formal_character_validator_partial_snapshot_contract(_harness))

func test_formal_character_validator_present_character_scope_contract() -> void:
	_assert_legacy_result(_test_formal_character_validator_present_character_scope_contract(_harness))

func test_formal_character_validator_absent_bad_validator_ignored_contract() -> void:
	_assert_legacy_result(_test_formal_character_validator_absent_bad_validator_ignored_contract(_harness))

func test_formal_character_validator_present_bad_validator_fail_fast_contract() -> void:
	_assert_legacy_result(_test_formal_character_validator_present_bad_validator_fail_fast_contract(_harness))
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
		if msg.find("formal[gojo_satoru].murasaki_burst required_target_same_owner must be true") != -1:
			saw_gojo_scope_error = true
		if msg.find("formal[sukuna]") != -1 or msg.find("formal[kashimo_hajime]") != -1:
			return harness.fail_result("scoped formal validator should not report unrelated characters when only Gojo is loaded")
	if not saw_gojo_scope_error:
		return harness.fail_result("scoped formal validator should still enforce Gojo contracts when Gojo is present")
	return harness.pass_result()

func _test_formal_character_validator_absent_bad_validator_ignored_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var manifest_path := "user://formal_character_manifest_absent_bad_validator_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_manifest_character_entry(
			"gojo_satoru",
			"Gojo",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"src/battle_core/content/formal_validators/gojo/content_snapshot_formal_gojo_validator.gd",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"test/suites/gojo_setup_and_markers_suite.gd",
			["test/suites/formal_character_pair_smoke/surface_suite.gd"],
			["gojo_manager_public_contracts"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
		_build_manifest_character_entry(
			"sukuna",
			"宿傩",
			"sukuna",
			"sukuna_setup",
			["content/units/sukuna/sukuna.tres"],
			InvalidValidatorFixturePath,
			"docs/design/sukuna_design.md",
			"docs/design/sukuna_adjustments.md",
			"sukuna_kai",
			"test/suites/sukuna_setup_loadout_regen_suite.gd",
			["test/suites/formal_character_pair_smoke/surface_suite.gd"],
			["sukuna_manager_public_contracts"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write absent-bad-validator manifest fixture")
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(gojo_only_paths):
		return harness.fail_result("gojo-only snapshot should load for absent-bad-validator contract: %s" % content_index.last_error_message)
	var validator = ContentSnapshotFormalCharacterValidatorScript.new()
	validator.registry_path_override = manifest_path
	var errors: Array = []
	validator.validate(content_index, errors)
	if not errors.is_empty():
		return harness.fail_result("absent formal character bad validator should not affect current snapshot: %s" % "\n".join(errors))
	return harness.pass_result()

func _test_formal_character_validator_present_bad_validator_fail_fast_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var manifest_path := "user://formal_character_manifest_present_bad_validator_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_manifest_character_entry(
			"gojo_satoru",
			"Gojo",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			InvalidValidatorFixturePath,
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"test/suites/gojo_setup_and_markers_suite.gd",
			["test/suites/formal_character_pair_smoke/surface_suite.gd"],
			["gojo_manager_public_contracts"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write present-bad-validator manifest fixture")
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		return harness.fail_result(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(gojo_only_paths):
		return harness.fail_result("gojo-only snapshot should load for present-bad-validator contract: %s" % content_index.last_error_message)
	var validator = ContentSnapshotFormalCharacterValidatorScript.new()
	validator.registry_path_override = manifest_path
	var errors: Array = []
	validator.validate(content_index, errors)
	if errors.is_empty():
		return harness.fail_result("present formal character bad validator should fail-fast during scoped validation")
	for raw_error in errors:
		if String(raw_error).find("failed to instantiate validator") != -1:
			return harness.pass_result()
	return harness.fail_result("present formal character bad validator should report instantiation failure")
