extends "res://test/suites/content_validation_core/formal_registry/shared.gd"


func test_formal_character_validator_partial_snapshot_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var sample_only_content = BattleContentIndexScript.new()
	var sample_only_paths: Variant = _build_filtered_snapshot_paths(_harness, sample_factory, PackedStringArray(["/gojo/", "/sukuna/", "/kashimo/", "/obito/"]))
	if sample_only_paths is Dictionary and sample_only_paths.has("error"):
		fail(str(sample_only_paths.get("error", "sample-only snapshot path build failed")))
		return
	if not sample_only_content.load_snapshot(sample_only_paths):
		fail("sample-only snapshot should validate without formal character assets: %s" % sample_only_content.last_error_message)
		return
	var gojo_only_content = BattleContentIndexScript.new()
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(_harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		fail(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
		return
	if not gojo_only_content.load_snapshot(gojo_only_paths):
		fail("gojo-only snapshot should validate without unrelated formal characters: %s" % gojo_only_content.last_error_message)
		return
	if not gojo_only_content.units.has("gojo_satoru") or gojo_only_content.units.has("sukuna") or gojo_only_content.units.has("kashimo_hajime") or gojo_only_content.units.has("obito_juubi_jinchuriki"):
		fail("gojo-only snapshot filter should keep only Gojo formal assets")
		return

func test_formal_character_validator_present_character_scope_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = BattleContentIndexScript.new()
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(_harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		fail(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
		return
	if not content_index.load_snapshot(gojo_only_paths):
		fail("gojo-only snapshot should load before scoped validation probe: %s" % content_index.last_error_message)
		return
	var burst_effect = content_index.effects.get("gojo_murasaki_conditional_burst", null)
	if burst_effect == null:
		fail("gojo-only snapshot missing gojo_murasaki_conditional_burst")
		return
	burst_effect.required_target_same_owner = false
	var errors: Array = content_index.validate_snapshot()
	var saw_gojo_scope_error := false
	for error_msg in errors:
		var msg := str(error_msg)
		if msg.find("formal[gojo_satoru].murasaki_burst required_target_same_owner must be true") != -1:
			saw_gojo_scope_error = true
		if msg.find("formal[sukuna]") != -1 or msg.find("formal[kashimo_hajime]") != -1:
			fail("scoped formal validator should not report unrelated characters when only Gojo is loaded")
			return
	if not saw_gojo_scope_error:
		fail("scoped formal validator should still enforce Gojo contracts when Gojo is present")
		return

func test_formal_character_validator_absent_bad_validator_ignored_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
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
			["formal_character_manager_public_contract_matrix"],
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
			["formal_character_manager_public_contract_matrix"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		fail("failed to write absent-bad-validator manifest fixture")
		return
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(_harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		fail(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
		return
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(gojo_only_paths):
		fail("gojo-only snapshot should load for absent-bad-validator contract: %s" % content_index.last_error_message)
		return
	var validator = ContentSnapshotFormalCharacterValidatorScript.new()
	validator.registry_path_override = manifest_path
	var errors: Array = []
	validator.validate(content_index, errors)
	if not errors.is_empty():
		fail("absent formal character bad validator should not affect current snapshot: %s" % "\n".join(errors))
		return

func test_formal_character_validator_present_bad_validator_fail_fast_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
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
			["formal_character_manager_public_contract_matrix"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		fail("failed to write present-bad-validator manifest fixture")
		return
	var gojo_only_paths: Variant = _build_filtered_snapshot_paths(_harness, sample_factory, PackedStringArray(["/sukuna/", "/kashimo/", "/obito/"]))
	if gojo_only_paths is Dictionary and gojo_only_paths.has("error"):
		fail(str(gojo_only_paths.get("error", "gojo-only snapshot path build failed")))
		return
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(gojo_only_paths):
		fail("gojo-only snapshot should load for present-bad-validator contract: %s" % content_index.last_error_message)
		return
	var validator = ContentSnapshotFormalCharacterValidatorScript.new()
	validator.registry_path_override = manifest_path
	var errors: Array = []
	validator.validate(content_index, errors)
	if errors.is_empty():
		fail("present formal character bad validator should fail-fast during scoped validation")
		return
	for raw_error in errors:
		if String(raw_error).find("failed to instantiate validator") != -1:
			return
	fail("present formal character bad validator should report instantiation failure")

