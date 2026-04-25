extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

func _test_formal_character_registry_id_mismatch_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_mismatch_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_manifest_character_entry(
			"gojo_alias",
			"Gojo Alias",
			"gojo_satoru",
			"gojoalias_vs_sample",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"test/suites/gojo_setup_and_markers_suite.gd",
			["test/suites/formal_character_pair_smoke/surface_suite.gd"],
			["formal_character_manager_public_contract_matrix"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"],
			[],
			"gojoalias"
		),
		_build_manifest_character_entry(
			"sukuna_alias",
			"Sukuna Alias",
			"sukuna",
			"sukunaalias_setup",
			["content/units/sukuna/sukuna.tres"],
			"",
			"docs/design/sukuna_design.md",
			"docs/design/sukuna_adjustments.md",
			"sukuna_kai",
			"test/suites/sukuna_setup_loadout_regen_suite.gd",
			["test/suites/formal_character_pair_smoke/surface_suite.gd"],
			["formal_character_manager_public_contract_matrix"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"],
			[],
			"sukunaalias",
			"",
			[
				_build_owned_pair_interaction_spec(
					"gojo_alias",
					"gojo_sukuna_domain_cleanup",
					3612,
					3611
				)
			]
		),
	], {
		"gojoalias_vs_sample": {
			"p1_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"],
			"p2_units": ["sample_pyron", "sample_tidekit", "sample_mossaur"]
		},
		"sukunaalias_setup": {
			"p1_units": ["sukuna", "sample_mossaur", "sample_pyron"],
			"p2_units": ["sample_tidekit", "sample_pyron", "sample_mossaur"]
		}
	}), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write formal manifest mismatch fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for mismatch fixture")
	if harness.build_formal_character_ids(override_factory) != PackedStringArray(["gojo_alias", "sukuna_alias"]):
		return harness.fail_result("formal_character_ids should preserve registry character ids even when they differ from unit_definition_id")
	if harness.build_formal_unit_definition_ids(override_factory) != PackedStringArray(["gojo_satoru", "sukuna"]):
		return harness.fail_result("formal_unit_definition_ids should expose registry unit_definition_id order")
	var delivery_registry := FormalCharacterRegistryScript.new()
	var delivery_result: Dictionary = delivery_registry.load_entries_from_path_result(manifest_path)
	if not bool(delivery_result.get("ok", false)):
		return harness.fail_result("formal delivery registry mismatch fixture should load: %s" % String(delivery_result.get("error", "unknown error")))
	var delivery_entries: Array = delivery_result.get("entries", [])
	if delivery_entries.size() != 2 \
	or String(delivery_entries[0].get("character_id", "")) != "gojo_alias" \
	or String(delivery_entries[1].get("character_id", "")) != "sukuna_alias":
		return harness.fail_result("formal delivery registry should preserve character_id order for mismatch fixture")
	var setup_result: Dictionary = override_factory.build_formal_character_setup_result("gojo_alias")
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("build_formal_character_setup_result should resolve mismatch registry character_id: %s" % String(setup_result.get("error_message", "unknown error")))
	var battle_setup = setup_result.get("data", null)
	if battle_setup == null or battle_setup.sides.is_empty() or battle_setup.sides[0].unit_definition_ids[0] != "gojo_satoru":
		return harness.fail_result("formal setup should still resolve the real unit_definition_id when character_id differs")
	var pair_shared = FormalCharacterPairSmokeSharedScript.new()
	var surface_cases_result: Dictionary = override_factory.formal_pair_surface_cases_result()
	if not bool(surface_cases_result.get("ok", false)):
		return harness.fail_result("formal pair surface cases should load for mismatch fixture: %s" % String(surface_cases_result.get("error_message", "unknown error")))
	var matrix_result = pair_shared.validate_directed_surface_matrix(harness, override_factory, surface_cases_result.get("data", []))
	if not bool(matrix_result.get("ok", false)):
		return matrix_result
	var live_factory = harness.build_sample_factory()
	if live_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for public snapshot mismatch contract")
	var snapshot_result: Dictionary = live_factory.content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(snapshot_result.get("ok", false)):
		return harness.fail_result("live snapshot path build failed for mismatch setup: %s" % String(snapshot_result.get("error_message", "unknown error")))
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var create_result: Dictionary = manager.create_session({
		"battle_seed": 3613,
		"content_snapshot_paths": snapshot_result.get("data", PackedStringArray()),
		"battle_setup": battle_setup,
	})
	if not bool(create_result.get("ok", false)):
		return harness.fail_result("manager create_session should accept mismatch setup: %s" % String(create_result.get("error_message", "unknown error")))
	var public_snapshot: Dictionary = create_result.get("data", {}).get("public_snapshot", {})
	var manager_helper := ManagerContractTestHelperScript.new()
	var p1_active_snapshot := manager_helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if p1_active_snapshot.is_empty() or String(p1_active_snapshot.get("definition_id", "")) != "gojo_satoru":
		return harness.fail_result("public snapshot should still expose real unit definition ids when registry character_id differs")
	return harness.pass_result()
