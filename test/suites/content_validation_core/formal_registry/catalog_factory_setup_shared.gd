extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

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
	if not bool(load_result.get("ok", false)):
		return harness.fail_result("formal character registry should load cleanly for setup contract: %s" % String(load_result.get("error_message", "")))
	var entries: Array = load_result.get("data", [])
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

func _test_formal_character_auto_sample_matchup_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_auto_sample_fixture.json"
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
			"gojo_ao",
			"test/suites/gojo_suite.gd",
			["test/suites/formal_character_pair_smoke_suite.gd"],
			["gojo_manager_smoke_contract"],
			["anchor:gojo.design.success-lock-via-on_success_effect_ids"],
			["anchor:gojo.adjust.tests-impacted"]
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write auto sample matchup fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for auto sample matchup fixture")
	var setup_result: Dictionary = override_factory.build_formal_character_setup_result("gojo_alias")
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("auto-derived sample matchup should resolve formal setup without touching shared registry: %s" % String(setup_result.get("error_message", "unknown error")))
	var direct_setup_result: Dictionary = override_factory.build_setup_by_matchup_id_result("gojo_alias_vs_sample")
	if not bool(direct_setup_result.get("ok", false)):
		return harness.fail_result("auto-derived sample matchup should be directly loadable by matchup id: %s" % String(direct_setup_result.get("error_message", "unknown error")))
	if _setup_signature(setup_result.get("data", null)) != _setup_signature(direct_setup_result.get("data", null)):
		return harness.fail_result("formal setup should match the auto-derived sample matchup")
	var available_result: Dictionary = override_factory.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		return harness.fail_result("available_matchups_result should expose auto-derived sample matchup: %s" % String(available_result.get("error_message", "unknown error")))
	for raw_descriptor in available_result.get("data", []):
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor
		if String(descriptor.get("matchup_id", "")) != "gojo_alias_vs_sample":
			continue
		if String(descriptor.get("source", "")) != "formal":
			return harness.fail_result("auto-derived sample matchup should surface as formal descriptor")
		return harness.pass_result()
	return harness.fail_result("available_matchups_result should include the auto-derived sample matchup id")

func _test_formal_character_registry_id_mismatch_contract(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_mismatch_fixture.json"
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
			"gojo_ao",
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
			["anchor:sukuna.adjust.tests-impacted"],
			[],
			"",
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
