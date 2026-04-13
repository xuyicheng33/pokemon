extends "res://test/support/gdunit_suite_bridge.gd"

const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _helper = ManagerContractTestHelperScript.new()
var _support = KashimoTestSupportScript.new()



func test_kashimo_kyokyo_loadout_contract() -> void:
	_assert_legacy_result(_test_kashimo_kyokyo_loadout_contract(_harness))

func test_kashimo_kyokyo_vs_gojo_unlimited_void_contract() -> void:
	_assert_legacy_result(_test_kashimo_kyokyo_vs_gojo_unlimited_void_contract(_harness))
func _test_kashimo_kyokyo_loadout_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var snapshot_paths: PackedStringArray = snapshot_paths_payload.get("paths", PackedStringArray())
	var default_session = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 851,
		"content_snapshot_paths": snapshot_paths,
		"battle_setup": _support.build_kashimo_setup(sample_factory),
	}), "create_session(default kashimo)")
	if not bool(default_session.get("ok", false)):
		return harness.fail_result(str(default_session.get("error", "default kashimo create_session failed")))
	var default_session_id := String(default_session.get("data", {}).get("session_id", ""))
	var default_legal_actions = _helper.unwrap_ok(manager.get_legal_actions(default_session_id, "P1"), "get_legal_actions(default kashimo)")
	if not bool(default_legal_actions.get("ok", false)):
		return harness.fail_result(str(default_legal_actions.get("error", "default kashimo get_legal_actions failed")))
	var default_actions = default_legal_actions.get("data", null)
	if default_actions.legal_skill_ids.has("kashimo_kyokyo_katsura"):
		return harness.fail_result("default kashimo loadout should not expose kyokyo katsura")
	if not default_actions.legal_skill_ids.has("kashimo_feedback_strike"):
		return harness.fail_result("default kashimo loadout should still expose feedback strike")
	manager.close_session(default_session_id)
	var loadout_override := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])}
	var override_session = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 852,
		"content_snapshot_paths": snapshot_paths,
		"battle_setup": _support.build_kashimo_setup(sample_factory, loadout_override),
	}), "create_session(kashimo kyokyo loadout)")
	if not bool(override_session.get("ok", false)):
		return harness.fail_result(str(override_session.get("error", "kashimo kyokyo loadout create_session failed")))
	var override_session_id := String(override_session.get("data", {}).get("session_id", ""))
	var override_legal_actions = _helper.unwrap_ok(manager.get_legal_actions(override_session_id, "P1"), "get_legal_actions(kashimo kyokyo loadout)")
	if not bool(override_legal_actions.get("ok", false)):
		return harness.fail_result(str(override_legal_actions.get("error", "kashimo kyokyo loadout get_legal_actions failed")))
	var override_actions = override_legal_actions.get("data", null)
	if not override_actions.legal_skill_ids.has("kashimo_kyokyo_katsura"):
		return harness.fail_result("kashimo kyokyo loadout should expose kyokyo katsura in legal actions")
	if override_actions.legal_skill_ids.has("kashimo_feedback_strike"):
		return harness.fail_result("kashimo kyokyo loadout should not keep feedback strike when it is swapped out")
	manager.close_session(override_session_id)
	return harness.pass_result()

func _test_kashimo_kyokyo_vs_gojo_unlimited_void_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var seed_result = _support.find_gojo_domain_accuracy_probe_seed(harness, sample_factory, 853)
	if not bool(seed_result.get("ok", false)):
		return harness.fail_result(str(seed_result.get("error", "failed to find gojo domain accuracy probe seed")))
	var probe_seed := int(seed_result.get("seed", 0))
	var baseline_result = _support.run_gojo_domain_accuracy_case(harness, sample_factory, false, probe_seed)
	if not bool(baseline_result.get("ok", false)):
		return harness.fail_result(str(baseline_result.get("error", "baseline gojo domain accuracy case failed")))
	if int(baseline_result.get("damage", 0)) <= 0:
		return harness.fail_result("gojo domain should force authored ao to hit before kyokyo is cast")
	var protected_result = _support.run_gojo_domain_accuracy_case(harness, sample_factory, true, probe_seed)
	if not bool(protected_result.get("ok", false)):
		return harness.fail_result(str(protected_result.get("error", "protected gojo domain accuracy case failed")))
	if int(protected_result.get("damage", -1)) != 0:
		return harness.fail_result("kyokyo should restore gojo ao's original miss rate under a real gojo domain")
	if not bool(protected_result.get("nullify_active", false)):
		return harness.fail_result("kyokyo runtime path should apply nullify_field_accuracy before gojo ao resolves")
	return harness.pass_result()
