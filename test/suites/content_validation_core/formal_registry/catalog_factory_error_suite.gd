extends "res://test/suites/content_validation_core/formal_registry/shared.gd"



func test_sample_battle_factory_result_error_contract() -> void:
	_assert_legacy_result(_test_sample_battle_factory_result_error_contract(_harness))

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
