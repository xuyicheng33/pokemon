extends RefCounted
class_name KashimoSetupLoadoutSuite

const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _helper = ManagerContractTestHelperScript.new()
var _support = KashimoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("kashimo_kyokyo_loadout_contract", failures, Callable(self, "_test_kashimo_kyokyo_loadout_contract").bind(harness))
	runner.run_test("kashimo_kyokyo_vs_gojo_unlimited_void_contract", failures, Callable(self, "_test_kashimo_kyokyo_vs_gojo_unlimited_void_contract").bind(harness))

func _test_kashimo_kyokyo_loadout_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var default_session = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 851,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
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
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
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
	var baseline_result = _run_gojo_domain_accuracy_case(harness, sample_factory, false, 853)
	if not bool(baseline_result.get("ok", false)):
		return baseline_result
	if int(baseline_result.get("damage", 0)) <= 0:
		return harness.fail_result("gojo domain should force zero-accuracy ao to hit before kyokyo is cast")
	var protected_result = _run_gojo_domain_accuracy_case(harness, sample_factory, true, 854)
	if not bool(protected_result.get("ok", false)):
		return protected_result
	if int(protected_result.get("damage", -1)) != 0:
		return harness.fail_result("kyokyo should restore original zero accuracy under a real gojo domain")
	if not bool(protected_result.get("nullify_active", false)):
		return harness.fail_result("kyokyo runtime path should apply nullify_field_accuracy before gojo ao resolves")
	return harness.pass_result()

func _run_gojo_domain_accuracy_case(harness, sample_factory, use_kyokyo: bool, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"ok": false, "error": str(core_payload["error"])}
	var core = core_payload["core"]
	var content_index = harness.build_loaded_content_index(sample_factory)
	content_index.skills["gojo_ao"].accuracy = 0
	var p1_overrides := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])} if use_kyokyo else {}
	var battle_state = _support.build_battle_state(
		core,
		content_index,
		_support.build_kashimo_vs_gojo_setup(sample_factory, p1_overrides),
		seed
	)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var gojo = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or gojo == null:
		return {"ok": false, "error": "missing active units for real kyokyo vs gojo domain case"}
	gojo.current_mp = gojo.max_mp
	gojo.ultimate_points = gojo.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_ultimate_command(core, 1, "P2", "P2-A", "gojo_unlimited_void"),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		return {"ok": false, "error": "gojo domain should be active before testing kyokyo against real domain accuracy"}
	var hp_before: int = kashimo.current_hp
	core.service("battle_logger").reset()
	var p1_command = _support.build_manual_skill_command(core, 2, "P1", "P1-A", "kashimo_kyokyo_katsura") if use_kyokyo else _support.build_manual_wait_command(core, 2, "P1", "P1-A")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		p1_command,
		_support.build_manual_skill_command(core, 2, "P2", "P2-A", "gojo_ao"),
	])
	return {
		"ok": true,
		"damage": hp_before - kashimo.current_hp,
		"nullify_active": _has_rule_mod(kashimo, "nullify_field_accuracy"),
	}

func _has_rule_mod(unit_state, mod_kind: String) -> bool:
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == mod_kind:
			return true
	return false
