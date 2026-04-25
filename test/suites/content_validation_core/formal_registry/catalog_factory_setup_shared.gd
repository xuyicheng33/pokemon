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
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write auto sample matchup fixture")
	var override_factory = harness.build_sample_factory_with_overrides(manifest_path)
	if override_factory == null:
		return harness.fail_result("SampleBattleFactory init failed for auto sample matchup fixture")
	var setup_result: Dictionary = override_factory.build_formal_character_setup_result("gojo_alias")
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("auto-derived sample matchup should resolve formal setup without touching shared registry: %s" % String(setup_result.get("error_message", "unknown error")))
	var direct_setup_result: Dictionary = override_factory.build_setup_by_matchup_id_result("gojoalias_vs_sample")
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
		if String(descriptor.get("matchup_id", "")) != "gojoalias_vs_sample":
			continue
		if String(descriptor.get("source", "")) != "formal":
			return harness.fail_result("auto-derived sample matchup should surface as formal descriptor")
		return harness.pass_result()
	return harness.fail_result("available_matchups_result should include the auto-derived sample matchup id")
