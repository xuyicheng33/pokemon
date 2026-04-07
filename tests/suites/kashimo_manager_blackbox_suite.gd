extends RefCounted
class_name KashimoManagerBlackboxSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _helper = _smoke_helper.contracts()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("kashimo_manager_water_leak_public_contract", failures, Callable(self, "_test_kashimo_manager_water_leak_public_contract").bind(harness))

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
