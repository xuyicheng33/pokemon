extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

func _test_formal_pair_interaction_catalog_seed_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_missing_seed_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
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
			[
				_build_owned_pair_interaction_spec(
					"gojo_satoru",
					"gojo_sukuna_domain_cleanup",
					0,
					2661
				)
			]
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
	}), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write formal manifest missing-seed fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for missing-seed fixture")
	var interaction_cases_result: Dictionary = override_factory.formal_pair_interaction_cases_result()
	if bool(interaction_cases_result.get("ok", true)):
		return harness.fail_result("formal pair interaction catalog should fail fast when battle_seed is missing")
	if String(interaction_cases_result.get("error_message", "")).find("battle_seed must be positive integer") == -1:
		return harness.fail_result("formal pair interaction missing-seed error should mention battle_seed")
	return harness.pass_result()
