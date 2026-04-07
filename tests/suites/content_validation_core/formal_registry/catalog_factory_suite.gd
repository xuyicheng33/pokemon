extends "res://tests/suites/content_validation_core/formal_registry/shared.gd"

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("formal_character_shared_fire_burst_validation", failures, Callable(self, "_test_formal_character_shared_fire_burst_validation").bind(harness))
	runner.run_test("formal_character_setup_registry_runtime_contract", failures, Callable(self, "_test_formal_character_setup_registry_runtime_contract").bind(harness))
	runner.run_test("formal_character_registry_id_mismatch_contract", failures, Callable(self, "_test_formal_character_registry_id_mismatch_contract").bind(harness))
	runner.run_test("formal_pair_interaction_catalog_seed_contract", failures, Callable(self, "_test_formal_pair_interaction_catalog_seed_contract").bind(harness))
	runner.run_test("formal_pair_surface_delivery_skill_contract", failures, Callable(self, "_test_formal_pair_surface_delivery_skill_contract").bind(harness))
	runner.run_test("sample_battle_factory_result_error_contract", failures, Callable(self, "_test_sample_battle_factory_result_error_contract").bind(harness))

func _test_formal_character_shared_fire_burst_validation(harness) -> Dictionary:
	var shared_path := "res://content/shared/effects/sukuna_shared_fire_burst_damage.tres"
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var kamado_mark = content_index.effects.get("sukuna_kamado_mark", null)
	var kamado_explode = content_index.effects.get("sukuna_kamado_explode", null)
	var domain_expire_burst = content_index.effects.get("sukuna_domain_expire_burst", null)
	if kamado_mark == null or kamado_explode == null or domain_expire_burst == null:
		return harness.fail_result("missing Sukuna shared fire burst effects")
	if kamado_mark.payloads.is_empty() or kamado_explode.payloads.is_empty() or domain_expire_burst.payloads.is_empty():
		return harness.fail_result("missing Sukuna shared fire burst payload")
	if String(kamado_mark.payloads[0].resource_path) != shared_path or String(kamado_explode.payloads[0].resource_path) != shared_path or String(domain_expire_burst.payloads[0].resource_path) != shared_path:
		return harness.fail_result("Sukuna fire burst effects must all point to the shared payload resource")
	var drift_payload := DamagePayloadScript.new()
	drift_payload.payload_type = "damage"
	drift_payload.amount = 20
	drift_payload.use_formula = false
	drift_payload.combat_type_id = "fire"
	kamado_mark.payloads[0] = drift_payload
	var errors: Array = content_index.validate_snapshot()
	for error_msg in errors:
		if str(error_msg).find("formal[sukuna].shared_fire_burst effect[sukuna_kamado_mark] must reuse payload resource") != -1:
			return harness.pass_result()
	return harness.fail_result("formal shared fire burst validation should fail when Sukuna effects stop sharing one payload resource")

func _test_formal_character_setup_registry_runtime_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var load_result: Dictionary = FormalCharacterValidatorRegistryScript.load_entries()
	var error_message := String(load_result.get("error", ""))
	if not error_message.is_empty():
		return harness.fail_result("formal character registry should load cleanly for setup contract: %s" % error_message)
	var entries: Array = load_result.get("entries", [])
	var expected_ids := PackedStringArray()
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		var character_id := String(entry.get("character_id", "")).strip_edges()
		expected_ids.append(character_id)
		var matchup_id := String(entry.get("formal_setup_matchup_id", "")).strip_edges()
		if matchup_id.is_empty():
			return harness.fail_result("formal character registry[%s] missing formal_setup_matchup_id" % character_id)
		var expected_setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(matchup_id)
		if not bool(expected_setup_result.get("ok", false)):
			return harness.fail_result("formal character setup matchup missing from SampleBattleFactory: %s (%s)" % [
				matchup_id,
				String(expected_setup_result.get("error_message", "unknown error")),
			])
		var expected_setup = expected_setup_result.get("data", null)
		var actual_setup_result: Dictionary = sample_factory.build_formal_character_setup_result(character_id)
		if not bool(actual_setup_result.get("ok", false)):
			return harness.fail_result("build_formal_character_setup_result failed for %s: %s" % [
				character_id,
				String(actual_setup_result.get("error_message", "unknown error")),
			])
		var actual_setup = actual_setup_result.get("data", null)
		if _setup_signature(actual_setup) != _setup_signature(expected_setup):
			return harness.fail_result("formal character setup drifted from registry matchup for %s" % character_id)
	if harness.build_formal_character_ids(sample_factory) != expected_ids:
		return harness.fail_result("formal_character_ids should preserve registry file order")
	return harness.pass_result()

func _test_formal_character_registry_id_mismatch_contract(harness) -> Dictionary:
	var runtime_registry_path := "user://formal_character_runtime_registry_mismatch_fixture.json"
	var delivery_registry_path := "user://formal_character_delivery_registry_mismatch_fixture.json"
	var matchup_catalog_path := "user://formal_matchup_catalog_mismatch_fixture.json"
	var runtime_registry_payload := JSON.stringify([
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_alias_vs_sukuna_alias",
			["content/units/gojo/gojo_satoru.tres"]
		),
		_build_runtime_registry_entry(
			"sukuna_alias",
			"sukuna",
			"sukuna_alias_vs_gojo_alias",
			["content/units/sukuna/sukuna.tres"]
		),
	], "  ")
	var delivery_registry_payload := JSON.stringify([
		_build_delivery_registry_entry(
			"gojo_alias",
			"Gojo Alias",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"gojo_ao",
			"tests/suites/gojo_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
		_build_delivery_registry_entry(
			"sukuna_alias",
			"Sukuna Alias",
			"docs/design/sukuna_design.md",
			"docs/design/sukuna_adjustments.md",
			"sukuna_kai",
			"tests/suites/sukuna_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["sukuna_manager_smoke_contract"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"]
		),
	], "  ")
	var catalog_payload := JSON.stringify({
		"matchups": {
			"gojo_alias_vs_sukuna_alias": {
				"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
				"p2_units": ["sukuna", "sample_tidekit", "sample_mossaur"]
			},
			"sukuna_alias_vs_gojo_alias": {
				"p1_units": ["sukuna", "sample_tidekit", "sample_mossaur"],
				"p2_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"]
			}
		},
		"pair_interaction_cases": []
	}, "  ")
	if not _write_json_fixture(runtime_registry_path, runtime_registry_payload):
		return harness.fail_result("failed to write formal runtime registry mismatch fixture")
	if not _write_json_fixture(delivery_registry_path, delivery_registry_payload):
		return harness.fail_result("failed to write formal delivery registry mismatch fixture")
	if not _write_json_fixture(matchup_catalog_path, catalog_payload):
		return harness.fail_result("failed to write formal matchup mismatch fixture")
	var override_factory = harness.build_sample_factory_with_overrides(
		runtime_registry_path,
		matchup_catalog_path,
		delivery_registry_path
	)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for mismatch fixture")
	if harness.build_formal_character_ids(override_factory) != PackedStringArray(["gojo_alias", "sukuna_alias"]):
		return harness.fail_result("formal_character_ids should preserve registry character ids even when they differ from unit_definition_id")
	if harness.build_formal_unit_definition_ids(override_factory) != PackedStringArray(["gojo_satoru", "sukuna"]):
		return harness.fail_result("formal_unit_definition_ids should expose registry unit_definition_id order")
	var delivery_registry := FormalCharacterRegistryScript.new()
	var delivery_result: Dictionary = delivery_registry.load_entries_from_path_result(delivery_registry_path)
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

func _test_formal_pair_interaction_catalog_seed_contract(harness) -> Dictionary:
	var matchup_catalog_path := "user://formal_matchup_catalog_missing_seed_fixture.json"
	var catalog_payload := JSON.stringify({
		"matchups": {
		"gojo_vs_sukuna": {
			"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
			"p2_units": ["sukuna", "sample_tidekit", "sample_mossaur"]
		}
		},
		"pair_interaction_cases": [
			{
				"test_name": "formal_pair_gojo_vs_sukuna_interaction_contract",
				"scenario_id": "gojo_vs_sukuna_domain_cleanup",
				"character_ids": ["gojo_satoru", "sukuna"],
				"matchup_id": "gojo_vs_sukuna"
			}
		]
	}, "  ")
	if not _write_json_fixture(matchup_catalog_path, catalog_payload):
		return harness.fail_result("failed to write formal matchup missing-seed fixture")
	var override_factory = harness.build_sample_factory_with_overrides("", matchup_catalog_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for missing-seed fixture")
	var interaction_cases_result: Dictionary = override_factory.formal_pair_interaction_cases_result()
	if bool(interaction_cases_result.get("ok", true)):
		return harness.fail_result("formal pair interaction catalog should fail fast when battle_seed is missing")
	if String(interaction_cases_result.get("error_message", "")).find("battle_seed must be positive integer") == -1:
		return harness.fail_result("formal pair interaction missing-seed error should mention battle_seed")
	return harness.pass_result()

func _test_formal_pair_surface_delivery_skill_contract(harness) -> Dictionary:
	var runtime_registry_path := "user://formal_character_runtime_registry_surface_skill_fixture.json"
	var delivery_registry_path := "user://formal_character_delivery_registry_surface_skill_fixture.json"
	var matchup_catalog_path := "user://formal_matchup_catalog_surface_skill_fixture.json"
	var runtime_registry_payload := JSON.stringify([
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"gojo_alias_vs_sukuna_alias",
			["content/units/gojo/gojo_satoru.tres"]
		),
		_build_runtime_registry_entry(
			"sukuna_alias",
			"sukuna",
			"sukuna_alias_vs_gojo_alias",
			["content/units/sukuna/sukuna.tres"]
		),
	], "  ")
	var delivery_registry_payload := JSON.stringify([
		_build_delivery_registry_entry(
			"gojo_alias",
			"Gojo Alias",
			"docs/design/gojo_satoru_design.md",
			"docs/design/gojo_satoru_adjustments.md",
			"",
			"tests/suites/gojo_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
		_build_delivery_registry_entry(
			"sukuna_alias",
			"Sukuna Alias",
			"docs/design/sukuna_design.md",
			"docs/design/sukuna_adjustments.md",
			"sukuna_kai",
			"tests/suites/sukuna_suite.gd",
			["tests/suites/formal_character_pair_smoke_suite.gd"],
			["sukuna_manager_smoke_contract"],
			["anchor:sukuna.design.domain-expire-burst-kept"],
			["anchor:sukuna.adjust.tests-impacted"]
		),
	], "  ")
	var catalog_payload := JSON.stringify({
		"matchups": {
			"gojo_alias_vs_sukuna_alias": {
				"p1_units": ["gojo_satoru", "sample_mossaur", "sample_pyron"],
				"p2_units": ["sukuna", "sample_tidekit", "sample_mossaur"]
			},
			"sukuna_alias_vs_gojo_alias": {
				"p1_units": ["sukuna", "sample_tidekit", "sample_mossaur"],
				"p2_units": ["gojo_satoru", "sample_mossaur", "sample_tidekit"]
			}
		},
		"pair_interaction_cases": []
	}, "  ")
	if not _write_json_fixture(runtime_registry_path, runtime_registry_payload):
		return harness.fail_result("failed to write runtime registry surface-skill fixture")
	if not _write_json_fixture(delivery_registry_path, delivery_registry_payload):
		return harness.fail_result("failed to write delivery registry surface-skill fixture")
	if not _write_json_fixture(matchup_catalog_path, catalog_payload):
		return harness.fail_result("failed to write matchup catalog surface-skill fixture")
	var override_factory = harness.build_sample_factory_with_overrides(
		runtime_registry_path,
		matchup_catalog_path,
		delivery_registry_path
	)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for surface-skill fixture")
	var surface_cases_result: Dictionary = override_factory.formal_pair_surface_cases_result()
	if bool(surface_cases_result.get("ok", true)):
		return harness.fail_result("formal pair surface generation should fail fast when delivery registry misses surface_smoke_skill_id")
	if String(surface_cases_result.get("error_message", "")).find("surface_smoke_skill_id") == -1:
		return harness.fail_result("formal pair surface missing-skill error should mention surface_smoke_skill_id")
	return harness.pass_result()

func _test_sample_battle_factory_result_error_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var missing_matchup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result("missing_matchup")
	if bool(missing_matchup_result.get("ok", true)):
		return harness.fail_result("missing matchup should return result-style error")
	if String(missing_matchup_result.get("error_code", "")) != "invalid_battle_setup":
		return harness.fail_result("missing matchup should report invalid_battle_setup")
	var missing_character_result: Dictionary = sample_factory.build_formal_character_setup_result("missing_character")
	if bool(missing_character_result.get("ok", true)):
		return harness.fail_result("missing formal character should return result-style error")
	if String(missing_character_result.get("error_code", "")) != "invalid_battle_setup":
		return harness.fail_result("missing formal character should report invalid_battle_setup")
	if String(missing_character_result.get("error_message", "")).find("unknown character_id") == -1:
		return harness.fail_result("missing formal character should preserve downstream lookup error_message")
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var missing_demo_profile_result: Dictionary = sample_factory.build_demo_replay_input_for_profile_result(manager_payload["manager"], "missing_demo_profile")
	if bool(missing_demo_profile_result.get("ok", true)):
		return harness.fail_result("missing demo replay profile should return result-style error")
	if String(missing_demo_profile_result.get("error_code", "")) != "invalid_replay_input":
		return harness.fail_result("missing demo replay profile should report invalid_replay_input")
	if String(missing_demo_profile_result.get("error_message", "")).find("unknown demo replay profile") == -1:
		return harness.fail_result("missing demo replay profile should preserve lookup error_message")
	return harness.pass_result()
