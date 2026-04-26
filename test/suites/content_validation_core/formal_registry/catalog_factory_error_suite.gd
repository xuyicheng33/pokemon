extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

const MISSING_FORMAL_MATCHUP_CATALOG_PATH := "res://tests/fixtures/missing_formal_matchup_catalog.json"



func test_sample_battle_factory_result_error_contract() -> void:
	_assert_legacy_result(_test_sample_battle_factory_result_error_contract(_harness))

func test_formal_setup_matchup_id_baseline_collision_fails_fast() -> void:
	_assert_legacy_result(_test_formal_setup_matchup_id_baseline_collision_fails_fast(_harness))

func test_build_setup_by_matchup_id_surfaces_formal_catalog_load_failure() -> void:
	_assert_legacy_result(_test_build_setup_by_matchup_id_surfaces_formal_catalog_load_failure(_harness))

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

func _test_formal_setup_matchup_id_baseline_collision_fails_fast(harness) -> Dictionary:
	var manifest_path := "user://formal_character_manifest_baseline_collision_fixture.json"
	var manifest_payload := JSON.stringify(_build_manifest_payload([
		_build_runtime_registry_entry(
			"gojo_alias",
			"gojo_satoru",
			"sample_default",
			["content/units/gojo/gojo_satoru.tres"],
			"",
			"gojoalias"
		),
	]), "  ")
	if not _write_json_fixture(manifest_path, manifest_payload):
		return harness.fail_result("failed to write baseline collision manifest fixture")
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	sample_factory.configure_formal_manifest_path_override(manifest_path)
	var setup_result: Dictionary = sample_factory.build_formal_character_setup_result("gojo_alias")
	if bool(setup_result.get("ok", false)):
		return harness.fail_result("formal_setup_matchup_id colliding with baseline should fail")
	var error_message := String(setup_result.get("error_message", ""))
	if error_message.find("collides with baseline matchup_id") == -1:
		return harness.fail_result("baseline collision error should be explicit, got: %s" % error_message)
	return harness.pass_result()

func _test_build_setup_by_matchup_id_surfaces_formal_catalog_load_failure(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	sample_factory.configure_matchup_catalog_path_override(MISSING_FORMAL_MATCHUP_CATALOG_PATH)
	var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result("gojo_vs_sukuna")
	if bool(setup_result.get("ok", true)):
		return harness.fail_result("formal matchup lookup should fail when formal catalog cannot load")
	if String(setup_result.get("error_code", "")) != ErrorCodesScript.INVALID_BATTLE_SETUP:
		return harness.fail_result("formal matchup lookup failure should report invalid_battle_setup")
	var error_message := String(setup_result.get("error_message", ""))
	if error_message.find("failed to load formal matchup catalog") == -1:
		return harness.fail_result("formal matchup lookup failure should preserve catalog load context, got: %s" % error_message)
	return harness.pass_result()
