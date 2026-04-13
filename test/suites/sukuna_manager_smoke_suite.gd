extends "res://test/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = null
var _helper = null


func _ensure_helpers() -> void:
	if _smoke_helper != null and _helper != null:
		return
	_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
	_helper = _smoke_helper.contracts()


func before_test() -> void:
	_ensure_helpers()


func test_sukuna_manager_smoke_contract() -> void:
	_assert_legacy_result(_test_sukuna_manager_smoke_contract(_harness))

func test_sukuna_manager_domain_lifecycle_public_contract() -> void:
	_assert_legacy_result(_test_sukuna_manager_domain_lifecycle_public_contract(_harness))
func _test_sukuna_manager_smoke_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var ritual_loadout := PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])
	var battle_setup = harness.build_sample_setup(sample_factory, {"P1": {0: ritual_loadout}})
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
	battle_setup.sides[0].starting_index = 0
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1302, battle_setup)
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
	var damaged_actor_snapshot: Dictionary = _helper.find_unit_snapshot(damaged_snapshot_unwrap.get("data", {}), "P1", "P1-A")
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
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("sukuna manager smoke public snapshot malformed: %s" % shape_error)
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
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
	var close_unwrap = _smoke_helper.close_session(manager, session_id)
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()

func _test_sukuna_manager_domain_lifecycle_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_sample_setup(sample_factory)
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
	battle_setup.sides[0].starting_index = 0
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_mossaur", "sample_pyron", "sample_tidekit"])
	battle_setup.sides[1].starting_index = 0
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1304, battle_setup)
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	for turn_index in [1, 2, 3]:
		var sukuna_command = _helper.unwrap_ok(manager.build_command({
			"turn_index": turn_index,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sukuna_kai",
		}), "build_command(sukuna_kai)")
		if not bool(sukuna_command.get("ok", false)):
			return harness.fail_result(str(sukuna_command.get("error", "manager build_command failed")))
		var wait_command = _helper.unwrap_ok(manager.build_command({
			"turn_index": turn_index,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}), "build_command(wait)")
		if not bool(wait_command.get("ok", false)):
			return harness.fail_result(str(wait_command.get("error", "manager build_command failed")))
		var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
			sukuna_command.get("data", null),
			wait_command.get("data", null),
		]), "run_turn charge_sukuna")
		if not bool(run_turn_unwrap.get("ok", false)):
			return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_ultimate_ids.has("sukuna_fukuma_mizushi"):
		return harness.fail_result("sukuna manager domain path should expose fukuma mizushi after 3 regular casts")
	var domain_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 4,
		"command_type": CommandTypesScript.ULTIMATE,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "sukuna_fukuma_mizushi",
	}), "build_command(sukuna_fukuma_mizushi)")
	if not bool(domain_command.get("ok", false)):
		return harness.fail_result(str(domain_command.get("error", "manager build_command failed")))
	var wait_turn_4 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 4,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait turn4)")
	if not bool(wait_turn_4.get("ok", false)):
		return harness.fail_result(str(wait_turn_4.get("error", "manager build_command failed")))
	var domain_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		domain_command.get("data", null),
		wait_turn_4.get("data", null),
	]), "run_turn domain")
	if not bool(domain_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(domain_turn_unwrap.get("error", "manager run_turn failed")))
	var active_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot active_domain")
	if not bool(active_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(active_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var active_snapshot: Dictionary = active_snapshot_unwrap.get("data", {})
	if String(active_snapshot.get("field_id", "")) != "sukuna_malevolent_shrine_field":
		return harness.fail_result("sukuna manager domain path should expose active sukuna_malevolent_shrine_field")
	var wait_turn_5_p1 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 5,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
	}), "build_command(wait turn5 p1)")
	var wait_turn_5_p2 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 5,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait turn5 p2)")
	if not bool(wait_turn_5_p1.get("ok", false)) or not bool(wait_turn_5_p2.get("ok", false)):
		return harness.fail_result("sukuna manager domain path failed to build wait commands for turn 5")
	var turn_5_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		wait_turn_5_p1.get("data", null),
		wait_turn_5_p2.get("data", null),
	]), "run_turn turn5")
	if not bool(turn_5_unwrap.get("ok", false)):
		return harness.fail_result(str(turn_5_unwrap.get("error", "manager run_turn failed")))
	var pre_expire_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot pre_expire")
	if not bool(pre_expire_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(pre_expire_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var pre_expire_target: Dictionary = _helper.find_unit_snapshot(pre_expire_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	if pre_expire_target.is_empty():
		return harness.fail_result("sukuna manager domain path missing target snapshot before expire")
	var hp_before_expire := int(pre_expire_target.get("current_hp", -1))
	var wait_turn_6_p1 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 6,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
	}), "build_command(wait turn6 p1)")
	var wait_turn_6_p2 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 6,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait turn6 p2)")
	if not bool(wait_turn_6_p1.get("ok", false)) or not bool(wait_turn_6_p2.get("ok", false)):
		return harness.fail_result("sukuna manager domain path failed to build wait commands for turn 6")
	var turn_6_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		wait_turn_6_p1.get("data", null),
		wait_turn_6_p2.get("data", null),
	]), "run_turn turn6")
	if not bool(turn_6_unwrap.get("ok", false)):
		return harness.fail_result(str(turn_6_unwrap.get("error", "manager run_turn failed")))
	var expired_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot expired_domain")
	if not bool(expired_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(expired_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var expired_snapshot: Dictionary = expired_snapshot_unwrap.get("data", {})
	if expired_snapshot.get("field_id", null) != null:
		return harness.fail_result("sukuna manager domain path should clear field after natural expire")
	var expired_target: Dictionary = _helper.find_unit_snapshot(expired_snapshot, "P2", "P2-A")
	if expired_target.is_empty():
		return harness.fail_result("sukuna manager domain path missing target snapshot after expire")
	if int(expired_target.get("current_hp", -1)) >= hp_before_expire:
		return harness.fail_result("sukuna manager domain path should expose expire burst damage on target snapshot")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna manager domain path event log must stay public-safe")
	var close_unwrap = _smoke_helper.close_session(manager, session_id)
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()
