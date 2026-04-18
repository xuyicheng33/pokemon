extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

func _test_formal_pair_surface_delivery_skill_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_surface_skill_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_manifest_character_entry(
			"gojo_alias",
			"Gojo Alias",
			"gojo_satoru",
			"gojo_alias_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"",
			"test/suites/gojo_suite.gd",
			["test/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
		_build_manifest_character_entry(
			"sukuna_alias",
			"Sukuna Alias",
			"sukuna",
			"sukuna_alias_setup",
			["content/units/sukuna/sukuna.tres"],
			"",
			"docs/design/sukuna_design.md",
			"docs/design/sukuna_adjustments.md",
			"sukuna_kai",
			"test/suites/sukuna_suite.gd",
			["test/suites/formal_character_pair_smoke_suite.gd"],
			["sukuna_manager_smoke_contract"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"]
		),
	], {
		"gojo_alias_vs_sample": {
			"p1_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
			"p2_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"]
		},
		"sukuna_alias_setup": {
			"p1_units": ["sukuna", "sample_mossaur", "sample_pyron"],
			"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"]
		}
	}), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write manifest surface-skill fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for surface-skill fixture")
	var surface_cases_result: Dictionary = override_factory.formal_pair_surface_cases_result()
	if bool(surface_cases_result.get("ok", true)):
		return harness.fail_result("formal pair surface generation should fail fast when delivery registry misses surface_smoke_skill_id")
	if String(surface_cases_result.get("error_message", "")).find("surface_smoke_skill_id") == -1:
		return harness.fail_result("formal pair surface missing-skill error should mention surface_smoke_skill_id")
	return harness.pass_result()

func _test_formal_matchup_test_only_flag_contract(harness) -> Dictionary:
	var characters := [
		_build_manifest_character_entry(
			"gojo_satoru",
			"Gojo",
			"gojo_satoru",
			"gojo_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"test/suites/gojo_suite.gd",
			["test/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
		_build_manifest_character_entry(
			"sukuna",
			"宿傩",
			"sukuna",
			"sukuna_setup",
			["content/units/sukuna/sukuna.tres"],
			"",
			"docs/design/sukuna_design.md",
			"docs/design/sukuna_adjustments.md",
			"sukuna_kai",
			"test/suites/sukuna_suite.gd",
			["test/suites/formal_character_pair_smoke_suite.gd"],
			["sukuna_manager_smoke_contract"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"]
		),
	]
	var matchups := {
		"gojo_vs_sample": {
			"p1_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
			"p2_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"]
		},
		"sukuna_setup": {
			"p1_units": ["sukuna", "sample_mossaur", "sample_pyron"],
			"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"]
		},
		"gojo_training_vs_sukuna": {
			"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
			"p2_units": ["sukuna", "sample_tidekit", "sample_mossaur"],
			"test_only": true
		}
	}
	var manifest_path := "user://formal_character_manifest_test_only_fixture.json"
	characters[1]["owned_pair_interaction_specs"] = [
		_build_owned_pair_interaction_spec(
			"gojo_satoru",
			"gojo_sukuna_domain_cleanup",
			5125,
			4125
		)
	]
	var manifest_payload := JSON.stringify(_build_manifest_payload(characters, matchups), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write formal manifest test-only fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for test-only fixture")
	var surface_cases_result: Dictionary = override_factory.formal_pair_surface_cases_result()
	if not bool(surface_cases_result.get("ok", false)):
		return harness.fail_result("test_only matchup should be ignored by formal pair surface generation: %s" % String(surface_cases_result.get("error_message", "unknown error")))
	var pair_shared = FormalCharacterPairSmokeSharedScript.new()
	var matrix_result = pair_shared.validate_directed_surface_matrix(harness, override_factory, surface_cases_result.get("data", []))
	if not bool(matrix_result.get("ok", false)):
		return matrix_result
	var test_only_setup_result: Dictionary = override_factory.build_setup_by_matchup_id_result("gojo_training_vs_sukuna")
	if not bool(test_only_setup_result.get("ok", false)):
		return harness.fail_result("test_only matchup should remain manually loadable: %s" % String(test_only_setup_result.get("error_message", "unknown error")))

	var invalid_matchups = matchups.duplicate(true)
	invalid_matchups["gojo_training_vs_sukuna"]["test_only"] = "yes"
	var invalid_manifest_path := "user://formal_character_manifest_invalid_test_only_fixture.json"
	var invalid_manifest_payload := JSON.stringify(_build_manifest_payload(characters, invalid_matchups), "  ")
	if not _write_json_fixture(invalid_manifest_path, invalid_manifest_payload):
		return harness.fail_result("failed to write invalid test_only fixture")
	var invalid_factory = harness.build_sample_factory_with_overrides(invalid_manifest_path)
	if invalid_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for invalid test_only fixture")
	var invalid_surface_cases_result: Dictionary = invalid_factory.formal_pair_surface_cases_result()
	if bool(invalid_surface_cases_result.get("ok", true)):
		return harness.fail_result("non-boolean test_only should fail fast")
	if String(invalid_surface_cases_result.get("error_message", "")).find("test_only") == -1:
		return harness.fail_result("invalid test_only error should mention test_only")
	return harness.pass_result()
