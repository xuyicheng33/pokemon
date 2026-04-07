extends RefCounted
class_name SukunaManagerBlackboxSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _helper = _smoke_helper.contracts()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("sukuna_manager_kamado_on_exit_public_contract", failures, Callable(self, "_test_sukuna_manager_kamado_on_exit_public_contract").bind(harness))

func _test_sukuna_manager_kamado_on_exit_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "sukuna_setup")
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1331, battle_setup, "create_session(sukuna kamado)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "sukuna kamado create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var turn_one = _run_turn_result(manager, session_id, 1, "sukuna_hiraku", "wait")
	if not bool(turn_one.get("ok", false)):
		return harness.fail_result(str(turn_one.get("error", "sukuna kamado turn1 failed")))
	var pre_switch_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna kamado pre-switch)")
	if not bool(pre_switch_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(pre_switch_snapshot_unwrap.get("error", "sukuna kamado pre-switch snapshot failed")))
	var pre_switch_target: Dictionary = _helper.find_unit_snapshot(pre_switch_snapshot_unwrap.get("data", {}), "P2", "P2-A")
	var hp_before_switch := int(pre_switch_target.get("current_hp", -1))
	if not _helper.unit_snapshot_has_effect(pre_switch_target, "sukuna_kamado_mark"):
		return harness.fail_result("sukuna manager kamado path should expose kamado mark before switch")
	var turn_two = _run_turn_result(manager, session_id, 2, "wait", "switch:P2-B")
	if not bool(turn_two.get("ok", false)):
		return harness.fail_result(str(turn_two.get("error", "sukuna kamado turn2 failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(sukuna kamado)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "sukuna kamado snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var switched_target: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if int(switched_target.get("current_hp", -1)) >= hp_before_switch:
		return harness.fail_result("sukuna manager kamado on-exit path should reduce switched-out target HP")
	if _helper.unit_snapshot_has_effect(switched_target, "sukuna_kamado_mark"):
		return harness.fail_result("sukuna manager kamado on-exit path should clear kamado mark after switch")
	var active_target: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-B")
	if active_target.is_empty():
		return harness.fail_result("sukuna manager kamado on-exit path should expose switched-in target P2-B")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(sukuna kamado)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "sukuna kamado event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("sukuna manager kamado on-exit path event log must stay public-safe")
	var on_exit_damage_events := 0
	for event_snapshot in events:
		if String(event_snapshot.get("event_type", "")) != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(event_snapshot.get("trigger_name", "")) != "on_exit":
			continue
		if String(event_snapshot.get("target_public_id", "")) != "P2-A":
			continue
		on_exit_damage_events += 1
	if on_exit_damage_events != 1:
		return harness.fail_result("sukuna manager kamado on-exit path should expose exactly one public on_exit damage event")
	_smoke_helper.close_session(manager, session_id, "close_session(sukuna kamado)")
	return harness.pass_result()

func _run_turn_result(manager, session_id: String, turn_index: int, p1_action: String, p2_action: String) -> Dictionary:
	var p1_command = _build_command_result(manager, turn_index, "P1", "P1-A", p1_action)
	if not bool(p1_command.get("ok", false)):
		return p1_command
	var p2_command = _build_command_result(manager, turn_index, "P2", "P2-A", p2_action)
	if not bool(p2_command.get("ok", false)):
		return p2_command
	return _helper.unwrap_ok(manager.run_turn(session_id, [
		p1_command.get("data", null),
		p2_command.get("data", null),
	]), "run_turn(sukuna kamado)")

func _build_command_result(manager, turn_index: int, side_id: String, actor_public_id: String, action_spec: String) -> Dictionary:
	var command_payload := {
		"turn_index": turn_index,
		"command_source": "manual",
		"side_id": side_id,
		"actor_public_id": actor_public_id,
	}
	if action_spec == "wait":
		command_payload["command_type"] = CommandTypesScript.WAIT
	elif action_spec.begins_with("switch:"):
		command_payload["command_type"] = CommandTypesScript.SWITCH
		command_payload["target_public_id"] = String(action_spec.split(":", false, 1)[1]).strip_edges()
	else:
		command_payload["command_type"] = CommandTypesScript.SKILL
		command_payload["skill_id"] = action_spec
	return _helper.unwrap_ok(manager.build_command(command_payload), "build_command(sukuna kamado)")
