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


func test_gojo_manager_smoke_contract() -> void:
	_assert_legacy_result(_test_gojo_manager_smoke_contract(_harness))

func test_gojo_manager_domain_public_contract() -> void:
	_assert_legacy_result(_test_gojo_manager_domain_public_contract(_harness))
func _test_gojo_manager_smoke_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var ritual_loadout := PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
	var init_unwrap = _smoke_helper.create_session(
		manager,
		sample_factory,
		1301,
		harness.build_setup_by_matchup_id(sample_factory, "gojo_vs_sample", {"P1": {0: ritual_loadout}})
	)
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("gojo manager smoke should expose actor_public_id=P1-A")
	if not legal_actions.legal_skill_ids.has("gojo_reverse_ritual"):
		return harness.fail_result("gojo manager smoke should expose reverse ritual in legal actions")
	if legal_actions.legal_skill_ids.has("gojo_murasaki"):
		return harness.fail_result("gojo manager smoke should hide murasaki after loadout override")
	var wait_turn_1_p1 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
	}), "build_command(wait p1)")
	if not bool(wait_turn_1_p1.get("ok", false)):
		return harness.fail_result(str(wait_turn_1_p1.get("error", "manager build_command failed")))
	var strike_turn_1_p2 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
		"skill_id": "sample_strike",
	}), "build_command(sample_strike)")
	if not bool(strike_turn_1_p2.get("ok", false)):
		return harness.fail_result(str(strike_turn_1_p2.get("error", "manager build_command failed")))
	var first_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		wait_turn_1_p1.get("data", null),
		strike_turn_1_p2.get("data", null),
	]), "run_turn turn1")
	if not bool(first_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(first_turn_unwrap.get("error", "manager run_turn failed")))
	var damaged_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(damaged_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(damaged_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var damaged_snapshot: Dictionary = damaged_snapshot_unwrap.get("data", {})
	var damaged_actor_snapshot: Dictionary = _helper.find_unit_snapshot(damaged_snapshot, "P1", "P1-A")
	if damaged_actor_snapshot.is_empty():
		return harness.fail_result("gojo manager smoke missing actor public snapshot after damage")
	var damaged_hp := int(damaged_actor_snapshot.get("current_hp", -1))
	var max_hp := int(damaged_actor_snapshot.get("max_hp", -1))
	if damaged_hp <= 0 or max_hp <= 0 or damaged_hp >= max_hp:
		return harness.fail_result("gojo manager smoke should show damaged hp after turn 1")
	var ritual_turn_2_p1 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 2,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "gojo_reverse_ritual",
	}), "build_command(gojo_reverse_ritual)")
	if not bool(ritual_turn_2_p1.get("ok", false)):
		return harness.fail_result(str(ritual_turn_2_p1.get("error", "manager build_command failed")))
	var wait_turn_2_p2 = _helper.unwrap_ok(manager.build_command({
		"turn_index": 2,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait p2)")
	if not bool(wait_turn_2_p2.get("ok", false)):
		return harness.fail_result(str(wait_turn_2_p2.get("error", "manager build_command failed")))
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		ritual_turn_2_p1.get("data", null),
		wait_turn_2_p2.get("data", null),
	]), "run_turn turn2")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("gojo manager smoke public snapshot malformed: %s" % shape_error)
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if actor_snapshot.is_empty():
		return harness.fail_result("gojo manager smoke missing actor public snapshot")
	if int(actor_snapshot.get("current_hp", -1)) <= damaged_hp:
		return harness.fail_result("gojo manager smoke should heal after reverse ritual")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var event_log_snapshot: Dictionary = event_log_unwrap.get("data", {})
	var events: Array = event_log_snapshot.get("events", [])
	if events.is_empty():
		return harness.fail_result("gojo manager smoke event log should not be empty after run_turn")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("gojo manager smoke event log must stay public-safe")
	if not _helper.event_log_has_public_heal(events, "P1-A"):
		return harness.fail_result("gojo manager smoke event log should expose heal on P1-A")
	var close_unwrap = _smoke_helper.close_session(manager, session_id)
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()

func _test_gojo_manager_domain_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_sample_setup(sample_factory)
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
	battle_setup.sides[0].starting_index = 0
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_mossaur", "sample_pyron", "sample_tidekit"])
	battle_setup.sides[1].starting_index = 0
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1303, battle_setup)
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	for turn_index in [1, 2, 3]:
		var gojo_command = _helper.unwrap_ok(manager.build_command({
			"turn_index": turn_index,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "gojo_ao",
		}), "build_command(gojo_ao)")
		if not bool(gojo_command.get("ok", false)):
			return harness.fail_result(str(gojo_command.get("error", "manager build_command failed")))
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
			gojo_command.get("data", null),
			wait_command.get("data", null),
		]), "run_turn charge_gojo")
		if not bool(run_turn_unwrap.get("ok", false)):
			return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
		return harness.fail_result("gojo manager domain path should expose unlimited void after 3 regular casts")
	var domain_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 4,
		"command_type": CommandTypesScript.ULTIMATE,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "gojo_unlimited_void",
	}), "build_command(gojo_unlimited_void)")
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
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	if String(public_snapshot.get("field_id", "")) != "gojo_unlimited_void_field":
		return harness.fail_result("gojo manager domain path should expose active gojo_unlimited_void_field")
	var field_snapshot: Dictionary = public_snapshot.get("field", {})
	if String(field_snapshot.get("creator_public_id", "")) != "P1-A":
		return harness.fail_result("gojo manager domain path should expose P1-A as field creator")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("gojo manager domain path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "gojo_satoru"):
		return harness.fail_result("gojo manager domain path should expose gojo public action cast")
	var close_unwrap = _smoke_helper.close_session(manager, session_id)
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()
