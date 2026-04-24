extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

func _test_formal_pair_interaction_catalog_seed_contract(harness) -> Dictionary:
	var missing_seed_result := _assert_interaction_catalog_fails_for_payload(
		harness,
		"missing_seed",
		_build_two_character_manifest_payload([
			_build_owned_pair_interaction_spec(
				"gojo_satoru",
				"gojo_sukuna_domain_cleanup",
				0,
				2661
			)
		]),
		"battle_seed must be positive integer"
	)
	if not bool(missing_seed_result.get("ok", false)):
		return missing_seed_result
	return _assert_interaction_catalog_fails_for_payload(
		harness,
		"duplicate_seed",
		_build_two_character_manifest_payload([
			_build_owned_pair_interaction_spec(
				"gojo_satoru",
				"gojo_sukuna_domain_cleanup",
				2661,
				2661
			)
		]),
		"duplicated pair interaction battle_seed"
	)

func _assert_interaction_catalog_fails_for_payload(harness, fixture_name: String, manifest_payload: Dictionary, expected_error: String) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_%s_fixture.json" % fixture_name
	var manifest_text := JSON.stringify(manifest_payload, "  ")
	if not _write_json_fixture(manifest_path, manifest_text):
		return harness.fail_result("failed to write formal manifest %s fixture" % fixture_name)
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for %s fixture" % fixture_name)
	var interaction_cases_result: Dictionary = override_factory.formal_pair_interaction_cases_result()
	if bool(interaction_cases_result.get("ok", true)):
		return harness.fail_result("formal pair interaction catalog should fail fast for %s" % fixture_name)
	if String(interaction_cases_result.get("error_message", "")).find(expected_error) == -1:
		return harness.fail_result("formal pair interaction %s error should mention %s" % [fixture_name, expected_error])
	return harness.pass_result()

func _build_two_character_manifest_payload(owned_pair_interaction_specs: Array) -> Dictionary:
	return _build_manifest_payload([
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
			["anchor:sukuna.adjust.tests-impacted"],
			[],
			"",
			"",
			owned_pair_interaction_specs
		),
	], {
		"gojo_vs_sample": {
			"p1_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
			"p2_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"]
		},
		"sukuna_setup": {
			"p1_units": ["sukuna", "sample_mossaur", "sample_pyron"],
			"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"]
		}
	})
