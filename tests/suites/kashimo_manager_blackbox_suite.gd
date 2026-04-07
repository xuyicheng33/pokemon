extends RefCounted
class_name KashimoManagerBlackboxSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _helper = _smoke_helper.contracts()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("kashimo_manager_water_leak_public_contract", failures, Callable(self, "_test_kashimo_manager_water_leak_public_contract").bind(harness))
	runner.run_test("kashimo_manager_feedback_strike_public_contract", failures, Callable(self, "_test_kashimo_manager_feedback_strike_public_contract").bind(harness))
	runner.run_test("kashimo_manager_kyokyo_public_contract", failures, Callable(self, "_test_kashimo_manager_kyokyo_public_contract").bind(harness))

func _test_kashimo_manager_water_leak_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "kashimo_vs_sample")
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1341, battle_setup, "create_session(kashimo water leak)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "kashimo water leak create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var before_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(kashimo water leak before)")
	if not bool(before_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(before_snapshot_unwrap.get("error", "kashimo water leak pre snapshot failed")))
	var before_snapshot: Dictionary = before_snapshot_unwrap.get("data", {})
	var before_kashimo: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P1", "P1-A")
	var before_attacker: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P2", "P2-A")
	var before_mp := int(before_kashimo.get("current_mp", -1))
	var before_attacker_hp := int(before_attacker.get("current_hp", -1))
	var wait_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
	}), "build_command(kashimo wait)")
	var water_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
		"skill_id": "sample_tide_surge",
	}), "build_command(sample_tide_surge)")
	if not bool(wait_command.get("ok", false)) or not bool(water_command.get("ok", false)):
		return harness.fail_result("kashimo water leak path should build wait + sample_tide_surge commands")
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		wait_command.get("data", null),
		water_command.get("data", null),
	]), "run_turn(kashimo water leak)")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "kashimo water leak run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(kashimo water leak)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "kashimo water leak snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var kashimo_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	var attacker_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if before_mp - int(kashimo_snapshot.get("current_mp", -1)) != 15:
		return harness.fail_result("kashimo manager water leak path should reduce current_mp by exactly 15")
	if int(attacker_snapshot.get("current_hp", -1)) >= before_attacker_hp:
		return harness.fail_result("kashimo manager water leak path should counter-damage the water attacker")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(kashimo water leak)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "kashimo water leak event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo manager water leak path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P2-A", "sample_tidekit"):
		return harness.fail_result("kashimo manager water leak path should expose attacker public action cast")
	_smoke_helper.close_session(manager, session_id, "close_session(kashimo water leak)")
	return harness.pass_result()

func _test_kashimo_manager_feedback_strike_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "kashimo_vs_sample")
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1342, battle_setup, "create_session(kashimo feedback strike)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "kashimo feedback create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	for turn_spec in [
		{"turn_index": 1, "p1_skill_id": "kashimo_raiken"},
		{"turn_index": 2, "p1_skill_id": "kashimo_charge"},
	]:
		var kashimo_command = _helper.unwrap_ok(manager.build_command({
			"turn_index": int(turn_spec["turn_index"]),
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": String(turn_spec["p1_skill_id"]),
		}), "build_command(%s)" % String(turn_spec["p1_skill_id"]))
		var wait_command = _helper.unwrap_ok(manager.build_command({
			"turn_index": int(turn_spec["turn_index"]),
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}), "build_command(wait)")
		if not bool(kashimo_command.get("ok", false)) or not bool(wait_command.get("ok", false)):
			return harness.fail_result("kashimo feedback setup should build public commands for raiken/charge")
		var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
			kashimo_command.get("data", null),
			wait_command.get("data", null),
		]), "run_turn(kashimo feedback setup)")
		if not bool(run_turn_unwrap.get("ok", false)):
			return harness.fail_result(str(run_turn_unwrap.get("error", "kashimo feedback setup run_turn failed")))
	var before_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(kashimo feedback before)")
	if not bool(before_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(before_snapshot_unwrap.get("error", "kashimo feedback pre snapshot failed")))
	var before_snapshot: Dictionary = before_snapshot_unwrap.get("data", {})
	var actor_before: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P1", "P1-A")
	var target_before: Dictionary = _helper.find_unit_snapshot(before_snapshot, "P2", "P2-A")
	if not _helper.unit_snapshot_has_effect(actor_before, "kashimo_positive_charge_mark"):
		return harness.fail_result("kashimo feedback public path should expose positive charge before cast")
	if not _helper.unit_snapshot_has_effect(target_before, "kashimo_negative_charge_mark"):
		return harness.fail_result("kashimo feedback public path should expose negative charge before cast")
	var target_hp_before := int(target_before.get("current_hp", -1))
	var feedback_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 3,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "kashimo_feedback_strike",
	}), "build_command(kashimo_feedback_strike)")
	var wait_turn_three = _helper.unwrap_ok(manager.build_command({
		"turn_index": 3,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait turn3)")
	if not bool(feedback_command.get("ok", false)) or not bool(wait_turn_three.get("ok", false)):
		return harness.fail_result("kashimo feedback path should build public feedback_strike command")
	var feedback_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		feedback_command.get("data", null),
		wait_turn_three.get("data", null),
	]), "run_turn(kashimo feedback)")
	if not bool(feedback_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(feedback_turn_unwrap.get("error", "kashimo feedback run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(kashimo feedback)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "kashimo feedback snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var actor_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if _helper.unit_snapshot_has_effect(actor_snapshot, "kashimo_positive_charge_mark"):
		return harness.fail_result("kashimo feedback public path should clear positive charge after cast")
	if _helper.unit_snapshot_has_effect(target_snapshot, "kashimo_negative_charge_mark"):
		return harness.fail_result("kashimo feedback public path should clear negative charge after cast")
	if int(target_snapshot.get("current_hp", -1)) >= target_hp_before:
		return harness.fail_result("kashimo feedback public path should damage the target")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(kashimo feedback)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "kashimo feedback event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo feedback public path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
		return harness.fail_result("kashimo feedback public path should expose kashimo public action cast")
	_smoke_helper.close_session(manager, session_id, "close_session(kashimo feedback)")
	return harness.pass_result()

func _test_kashimo_manager_kyokyo_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var override_loadout := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])}
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "kashimo_vs_sample", {"P1": override_loadout})
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, 1343, battle_setup, "create_session(kashimo kyokyo)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "kashimo kyokyo create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions(kashimo kyokyo)")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "kashimo kyokyo legal actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if not legal_actions.legal_skill_ids.has("kashimo_kyokyo_katsura"):
		return harness.fail_result("kashimo kyokyo public path should expose 弥虚葛笼 in legal actions")
	var kyokyo_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "kashimo_kyokyo_katsura",
	}), "build_command(kashimo_kyokyo_katsura)")
	var wait_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait)")
	if not bool(kyokyo_command.get("ok", false)) or not bool(wait_command.get("ok", false)):
		return harness.fail_result("kashimo kyokyo public path should build public commands")
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		kyokyo_command.get("data", null),
		wait_command.get("data", null),
	]), "run_turn(kashimo kyokyo)")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "kashimo kyokyo run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(kashimo kyokyo)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "kashimo kyokyo snapshot failed")))
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(kashimo kyokyo)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "kashimo kyokyo event log failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	var has_nullify_apply := false
	for event_snapshot in events:
		if String(event_snapshot.get("event_type", "")) != EventTypesScript.EFFECT_RULE_MOD_APPLY:
			continue
		if String(event_snapshot.get("target_public_id", "")) != "P1-A":
			continue
		if String(event_snapshot.get("payload_summary", "")).find("nullify_field_accuracy") == -1:
			continue
		has_nullify_apply = true
		break
	if not has_nullify_apply:
		return harness.fail_result("kashimo kyokyo public path should expose nullify_field_accuracy apply in public event log")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("kashimo kyokyo public path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "kashimo_hajime"):
		return harness.fail_result("kashimo kyokyo public path should expose kashimo public action cast")
	_smoke_helper.close_session(manager, session_id, "close_session(kashimo kyokyo)")
	return harness.pass_result()
