extends "res://test/support/gdunit_suite_bridge.gd"

const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = null
var _helper = null
var _case_specs: Array = []


func _ensure_suite_state() -> void:
	if _smoke_helper == null or _helper == null:
		_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
		_helper = _smoke_helper.contracts()
	if _case_specs.is_empty():
		_case_specs = [
			{
				"test_name": "test_gojo_manager_murasaki_combo_public_contract",
				"session_mode": "manual",
				"run_case": Callable(self, "_run_gojo_manager_murasaki_combo_case"),
			},
		]


func before_test() -> void:
	_ensure_suite_state()


func test_gojo_manager_murasaki_combo_public_contract() -> void:
	_assert_legacy_result(_test_gojo_manager_murasaki_combo_public_contract(_harness))


func _test_gojo_manager_murasaki_combo_public_contract(harness) -> Dictionary:
	return _smoke_helper.run_named_case(harness, _case_specs, "test_gojo_manager_murasaki_combo_public_contract")


func _run_gojo_manager_murasaki_combo_case(state: Dictionary) -> Dictionary:
	var harness = state["harness"]
	var manager = state["manager"]
	var sample_factory = state["sample_factory"]
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
	var turn_specs: Array = []
	for turn_offset in range(skill_ids.size()):
		var turn_index := turn_offset + 1
		var skill_id := String(skill_ids[turn_offset]).strip_edges()
		turn_specs.append({
			"turn_index": turn_index,
			"label": "run_turn(gojo combo)",
			"p1_action": "wait" if skill_id == "wait" else skill_id,
			"p2_action": "wait",
			"p1_label": "build_command(gojo sequence)",
			"p2_label": "build_command(gojo combo wait)",
		})
	var run_turns = _smoke_helper.run_turn_sequence_result(manager, session_id, turn_specs)
	if not bool(run_turns.get("ok", false)):
		return {"ok": false, "error": str(run_turns.get("error", "gojo combo run_turn failed"))}
	var public_snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(gojo combo)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return {"ok": false, "error": str(public_snapshot_unwrap.get("error", "gojo combo snapshot failed"))}
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var target_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(gojo combo)")
	if not bool(event_log_unwrap.get("ok", false)):
		return {"ok": false, "error": str(event_log_unwrap.get("error", "gojo combo event log failed"))}
	_smoke_helper.close_session(manager, session_id, "close_session(gojo combo)")
	return {
		"ok": true,
		"target_hp": int(target_snapshot.get("current_hp", -1)),
		"target_snapshot": target_snapshot,
		"events": event_log_unwrap.get("data", {}).get("events", []),
	}
