extends RefCounted
class_name GojoManagerBlackboxSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _helper = _smoke_helper.contracts()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("gojo_manager_murasaki_combo_public_contract", failures, Callable(self, "_test_gojo_manager_murasaki_combo_public_contract").bind(harness))

func _test_gojo_manager_murasaki_combo_public_contract(harness) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var baseline_result := _run_gojo_sequence_result(manager, sample_factory, harness, 1321, ["wait", "wait", "gojo_murasaki"])
	if not bool(baseline_result.get("ok", false)):
		return harness.fail_result(str(baseline_result.get("error", "gojo baseline manager combo case failed")))
	var combo_result := _run_gojo_sequence_result(manager, sample_factory, harness, 1322, ["gojo_ao", "gojo_aka", "gojo_murasaki"])
	if not bool(combo_result.get("ok", false)):
		return harness.fail_result(str(combo_result.get("error", "gojo combo manager case failed")))
	if int(combo_result.get("target_hp", -1)) >= int(baseline_result.get("target_hp", -1)):
		return harness.fail_result("gojo manager combo path should leave target HP lower than baseline murasaki path")
	var target_snapshot: Dictionary = combo_result.get("target_snapshot", {})
	if _helper.unit_snapshot_has_effect(target_snapshot, "gojo_ao_mark") or _helper.unit_snapshot_has_effect(target_snapshot, "gojo_aka_mark"):
		return harness.fail_result("gojo manager combo path should clear ao/aka marks after murasaki burst")
	var events: Array = combo_result.get("events", [])
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("gojo manager combo path event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", "gojo_satoru"):
		return harness.fail_result("gojo manager combo path should expose gojo public action cast")
	return harness.pass_result()

func _run_gojo_sequence_result(manager, sample_factory, harness, battle_seed: int, skill_ids: Array) -> Dictionary:
	var battle_setup = harness.build_setup_by_matchup_id(sample_factory, "gojo_vs_sample")
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, battle_seed, battle_setup, "create_session(gojo manager combo)")
	if not bool(init_unwrap.get("ok", false)):
		return {"ok": false, "error": str(init_unwrap.get("error", "gojo combo create_session failed"))}
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	for turn_offset in range(skill_ids.size()):
		var turn_index := turn_offset + 1
		var skill_id := String(skill_ids[turn_offset]).strip_edges()
		var p1_command = _helper.unwrap_ok(manager.build_command({
			"turn_index": turn_index,
			"command_type": CommandTypesScript.WAIT if skill_id == "wait" else CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": skill_id,
		}), "build_command(gojo sequence)")
		if not bool(p1_command.get("ok", false)):
			return {"ok": false, "error": str(p1_command.get("error", "gojo combo build_command failed"))}
		var p2_command = _helper.unwrap_ok(manager.build_command({
			"turn_index": turn_index,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}), "build_command(gojo combo wait)")
		if not bool(p2_command.get("ok", false)):
			return {"ok": false, "error": str(p2_command.get("error", "gojo combo wait build failed"))}
		var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
			p1_command.get("data", null),
			p2_command.get("data", null),
		]), "run_turn(gojo combo)")
		if not bool(run_turn_unwrap.get("ok", false)):
			return {"ok": false, "error": str(run_turn_unwrap.get("error", "gojo combo run_turn failed"))}
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(gojo combo)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return {"ok": false, "error": str(public_snapshot_unwrap.get("error", "gojo combo snapshot failed"))}
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(gojo combo)")
	if not bool(event_log_unwrap.get("ok", false)):
		return {"ok": false, "error": str(event_log_unwrap.get("error", "gojo combo event log failed"))}
	_smoke_helper.close_session(manager, session_id, "close_session(gojo combo)")
	return {
		"ok": true,
		"target_hp": int(target_snapshot.get("current_hp", -1)),
		"target_snapshot": target_snapshot,
		"events": event_log_unwrap.get("data", {}).get("events", []),
	}
