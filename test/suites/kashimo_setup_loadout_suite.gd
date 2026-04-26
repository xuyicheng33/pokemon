extends "res://tests/support/gdunit_suite_bridge.gd"

const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _helper = ManagerContractTestHelperScript.new()
var _support = KashimoTestSupportScript.new()


func test_kashimo_kyokyo_loadout_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var snapshot_paths: PackedStringArray = snapshot_paths_payload.get("paths", PackedStringArray())
	var default_session = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 851,
		"content_snapshot_paths": snapshot_paths,
		"battle_setup": _support.build_kashimo_setup(sample_factory),
	}), "create_session(default kashimo)")
	if not bool(default_session.get("ok", false)):
		fail(str(default_session.get("error", "default kashimo create_session failed")))
		return
	var default_session_id := String(default_session.get("data", {}).get("session_id", ""))
	var default_legal_actions = _helper.unwrap_ok(manager.get_legal_actions(default_session_id, "P1"), "get_legal_actions(default kashimo)")
	if not bool(default_legal_actions.get("ok", false)):
		fail(str(default_legal_actions.get("error", "default kashimo get_legal_actions failed")))
		return
	var default_actions = default_legal_actions.get("data", null)
	if default_actions.legal_skill_ids.has("kashimo_kyokyo_katsura"):
		fail("default kashimo loadout should not expose kyokyo katsura")
		return
	if not default_actions.legal_skill_ids.has("kashimo_feedback_strike"):
		fail("default kashimo loadout should still expose feedback strike")
		return
	manager.close_session(default_session_id)
	var loadout_override := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])}
	var override_session = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 852,
		"content_snapshot_paths": snapshot_paths,
		"battle_setup": _support.build_kashimo_setup(sample_factory, loadout_override),
	}), "create_session(kashimo kyokyo loadout)")
	if not bool(override_session.get("ok", false)):
		fail(str(override_session.get("error", "kashimo kyokyo loadout create_session failed")))
		return
	var override_session_id := String(override_session.get("data", {}).get("session_id", ""))
	var override_legal_actions = _helper.unwrap_ok(manager.get_legal_actions(override_session_id, "P1"), "get_legal_actions(kashimo kyokyo loadout)")
	if not bool(override_legal_actions.get("ok", false)):
		fail(str(override_legal_actions.get("error", "kashimo kyokyo loadout get_legal_actions failed")))
		return
	var override_actions = override_legal_actions.get("data", null)
	if not override_actions.legal_skill_ids.has("kashimo_kyokyo_katsura"):
		fail("kashimo kyokyo loadout should expose kyokyo katsura in legal actions")
		return
	if override_actions.legal_skill_ids.has("kashimo_feedback_strike"):
		fail("kashimo kyokyo loadout should not keep feedback strike when it is swapped out")
		return
	manager.close_session(override_session_id)

func test_kashimo_kyokyo_vs_gojo_unlimited_void_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var seed_result = _support.find_gojo_domain_accuracy_probe_seed(_harness, sample_factory, 853)
	if not bool(seed_result.get("ok", false)):
		fail(str(seed_result.get("error", "failed to find gojo domain accuracy probe seed")))
		return
	var probe_seed := int(seed_result.get("seed", 0))
	var baseline_result = _support.run_gojo_domain_accuracy_case(_harness, sample_factory, false, probe_seed)
	if not bool(baseline_result.get("ok", false)):
		fail(str(baseline_result.get("error", "baseline gojo domain accuracy case failed")))
		return
	if int(baseline_result.get("damage", 0)) <= 0:
		fail("gojo domain should force authored ao to hit before kyokyo is cast")
		return
	var protected_result = _support.run_gojo_domain_accuracy_case(_harness, sample_factory, true, probe_seed)
	if not bool(protected_result.get("ok", false)):
		fail(str(protected_result.get("error", "protected gojo domain accuracy case failed")))
		return
	if int(protected_result.get("damage", -1)) != 0:
		fail("kyokyo should restore gojo ao's original miss rate under a real gojo domain")
		return
	if not bool(protected_result.get("nullify_active", false)):
		fail("kyokyo runtime path should apply nullify_field_accuracy before gojo ao resolves")
		return

