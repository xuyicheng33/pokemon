extends RefCounted
class_name SukunaManagerSmokeSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("sukuna_manager_smoke_contract", failures, Callable(self, "_test_sukuna_manager_smoke_contract").bind(harness))

func _test_sukuna_manager_smoke_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var ritual_loadout := PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])
	var battle_setup = sample_factory.build_sample_setup({"P1": {0: ritual_loadout}})
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
	battle_setup.sides[0].starting_index = 0
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 1302,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": battle_setup,
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("sukuna manager smoke should expose actor_public_id=P1-A")
	if not legal_actions.legal_skill_ids.has("sukuna_reverse_ritual"):
		return harness.fail_result("sukuna manager smoke should expose reverse ritual in legal actions")
	if legal_actions.legal_skill_ids.has("sukuna_hiraku"):
		return harness.fail_result("sukuna manager smoke should hide hiraku after loadout override")
	var wait_p1_unwrap = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
	}), "build_command(wait_p1)")
	if not bool(wait_p1_unwrap.get("ok", false)):
		return harness.fail_result(str(wait_p1_unwrap.get("error", "manager build_command failed")))
	var strike_p2_unwrap = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
		"skill_id": "sample_strike",
	}), "build_command(sample_strike)")
	if not bool(strike_p2_unwrap.get("ok", false)):
		return harness.fail_result(str(strike_p2_unwrap.get("error", "manager build_command failed")))
	var setup_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		wait_p1_unwrap.get("data", null),
		strike_p2_unwrap.get("data", null),
	]), "run_turn_setup")
	if not bool(setup_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(setup_turn_unwrap.get("error", "manager setup run_turn failed")))
	var damaged_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot_after_damage")
	if not bool(damaged_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(damaged_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var damaged_actor_snapshot := _helper.find_unit_snapshot(damaged_snapshot_unwrap.get("data", {}), "P1", "P1-A")
	if damaged_actor_snapshot.is_empty():
		return harness.fail_result("sukuna manager smoke missing actor snapshot after setup turn")
	var before_hp := int(damaged_actor_snapshot.get("current_hp", -1))
	var max_hp := int(damaged_actor_snapshot.get("max_hp", -1))
	if before_hp <= 0 or max_hp <= 0 or before_hp >= max_hp:
		return harness.fail_result("sukuna manager smoke setup turn should leave actor damaged but alive")
	var expected_gain: int = min(max_hp - before_hp, max(1, int(floor(float(max_hp) * 0.25))))
	var ritual_command_unwrap = _helper.unwrap_ok(manager.build_command({
		"turn_index": 2,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "sukuna_reverse_ritual",
	}), "build_command(sukuna_reverse_ritual)")
	if not bool(ritual_command_unwrap.get("ok", false)):
		return harness.fail_result(str(ritual_command_unwrap.get("error", "manager build_command failed")))
	var wait_command_unwrap = _helper.unwrap_ok(manager.build_command({
		"turn_index": 2,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait)")
	if not bool(wait_command_unwrap.get("ok", false)):
		return harness.fail_result(str(wait_command_unwrap.get("error", "manager build_command failed")))
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		ritual_command_unwrap.get("data", null),
		wait_command_unwrap.get("data", null),
	]), "run_turn")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error := _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("sukuna manager smoke public snapshot malformed: %s" % shape_error)
	var actor_snapshot := _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if actor_snapshot.is_empty():
		return harness.fail_result("sukuna manager smoke missing actor public snapshot")
	if int(actor_snapshot.get("current_hp", -1)) != before_hp + expected_gain:
		return harness.fail_result("sukuna manager smoke public snapshot hp mismatch")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var event_log_snapshot: Dictionary = event_log_unwrap.get("data", {})
	var events: Array = event_log_snapshot.get("events", [])
	if events.is_empty():
		return harness.fail_result("sukuna manager smoke event log should not be empty after run_turn")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna manager smoke event log must stay public-safe")
	if not _helper.event_log_has_public_heal(events, "P1-A"):
		return harness.fail_result("sukuna manager smoke event log should expose heal on P1-A")
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()
