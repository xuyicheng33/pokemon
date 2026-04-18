extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

func _test_formal_pair_interaction_catalog_direction_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_derived_interaction_fixture.json"
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
					5123,
					4123
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
		return harness.fail_result("failed to write derived interaction fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for derived interaction fixture")
	var interaction_cases_result: Dictionary = override_factory.formal_pair_interaction_cases_result()
	if not bool(interaction_cases_result.get("ok", false)):
		return harness.fail_result("formal pair interaction catalog should derive directed cases from owned_pair_interaction_specs: %s" % String(interaction_cases_result.get("error_message", "unknown error")))
	var interaction_cases: Array = interaction_cases_result.get("data", [])
	if interaction_cases.size() != 2:
		return harness.fail_result("formal pair interaction catalog should derive exactly two directed cases from one spec")
	var case_by_matchup_id: Dictionary = {}
	for raw_case in interaction_cases:
		if not (raw_case is Dictionary):
			return harness.fail_result("formal pair interaction catalog should only emit dictionary cases")
		var interaction_case: Dictionary = raw_case
		case_by_matchup_id[String(interaction_case.get("matchup_id", ""))] = interaction_case
	var gojo_case: Dictionary = case_by_matchup_id.get("gojo_vs_sukuna", {})
	var sukuna_case: Dictionary = case_by_matchup_id.get("sukuna_vs_gojo", {})
	if gojo_case.is_empty() or sukuna_case.is_empty():
		return harness.fail_result("formal pair interaction catalog should derive stable directional matchup ids")
	if String(gojo_case.get("scenario_key", "")) != "gojo_sukuna_domain_cleanup" or String(sukuna_case.get("scenario_key", "")) != "gojo_sukuna_domain_cleanup":
		return harness.fail_result("formal pair interaction catalog should keep one stable scenario_key across both directions")
	if int(gojo_case.get("battle_seed", 0)) != 4123 or int(sukuna_case.get("battle_seed", 0)) != 5123:
		return harness.fail_result("formal pair interaction catalog should preserve forward/reverse battle seeds")
	return harness.pass_result()

func _test_formal_pair_interaction_catalog_test_only_matchup_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_test_only_interaction_fixture.json"
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
					5124,
					4124
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
		},
		"gojo_training_vs_sukuna": {
			"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
			"p2_units": ["sukuna", "sample_tidekit", "sample_mossaur"],
			"test_only": true
		}
	}), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write test_only interaction fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for test_only interaction fixture")
	var interaction_cases_result: Dictionary = override_factory.formal_pair_interaction_cases_result()
	if not bool(interaction_cases_result.get("ok", false)):
		return harness.fail_result("formal pair interaction catalog should ignore explicit test_only matchups outside the generated pair matrix: %s" % String(interaction_cases_result.get("error_message", "unknown error")))
	for raw_case in interaction_cases_result.get("data", []):
		var case_spec: Dictionary = raw_case
		if String(case_spec.get("matchup_id", "")) == "gojo_training_vs_sukuna":
			return harness.fail_result("formal pair interaction catalog must not derive cases against explicit test_only matchup ids")
	return harness.pass_result()
