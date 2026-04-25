extends "res://test/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()



func test_replay_snapshot_contract() -> void:
	_assert_legacy_result(_test_replay_snapshot_contract(_harness))

func test_log_v3_header_contract() -> void:
	_assert_legacy_result(_test_log_v3_header_contract(_harness))

func test_header_snapshot_private_id_guard() -> void:
	_assert_legacy_result(_test_header_snapshot_private_id_guard(_harness))

func test_replay_turn_timeline_matches_public_snapshot_contract() -> void:
	_assert_legacy_result(_test_replay_turn_timeline_matches_public_snapshot_contract(_harness))
func _test_replay_snapshot_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var live_unwrap = _unwrap_ok(manager.create_session({"battle_seed": 405, "content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()), "battle_setup": harness.build_sample_setup(sample_factory)}), "create_session")
	if not bool(live_unwrap.get("ok", false)):
		return harness.fail_result(str(live_unwrap.get("error", "manager create_session failed")))
	var live_snapshot = live_unwrap.get("data", {}).get("public_snapshot", {})
	var replay_unwrap = _unwrap_ok(manager.run_replay(harness.build_demo_replay_input(sample_factory, manager)), "run_replay")
	if not bool(replay_unwrap.get("ok", false)):
		return harness.fail_result(str(replay_unwrap.get("error", "manager run_replay failed")))
	var replay_snapshot = replay_unwrap.get("data", {}).get("public_snapshot", {})
	if typeof(replay_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("run_replay should expose public_snapshot")
	if not replay_snapshot.has("prebattle_public_teams"):
		return harness.fail_result("replay public_snapshot missing prebattle_public_teams")
	var shape_error = _helper.validate_snapshot_shape(replay_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("replay snapshot shape invalid: %s" % shape_error)
	var live_shape_error = _helper.validate_snapshot_shape(live_snapshot)
	if not live_shape_error.is_empty():
		return harness.fail_result("live snapshot shape invalid: %s" % live_shape_error)
	if replay_snapshot.get("visibility_mode", "") != live_snapshot.get("visibility_mode", ""):
		return harness.fail_result("replay snapshot visibility_mode should match live contract")
	return harness.pass_result()

func _test_log_v3_header_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_unwrap = _unwrap_ok(manager.run_replay(harness.build_demo_replay_input(sample_factory, manager)), "run_replay")
	if not bool(replay_unwrap.get("ok", false)):
		return harness.fail_result(str(replay_unwrap.get("error", "manager run_replay failed")))
	var replay_output = replay_unwrap.get("data", {}).get("replay_output", null)
	if replay_output == null:
		return harness.fail_result("run_replay should return replay_output")
	var header_count: int = 0
	var header_index: int = -1
	var first_enter_index: int = -1
	for i in range(replay_output.event_log.size()):
		var ev = replay_output.event_log[i]
		if not (ev is Dictionary):
			return harness.fail_result("manager replay event_log should expose public Dictionary events")
		if int(ev.get("log_schema_version", 0)) != 3:
			return harness.fail_result("log_schema_version should be 3 for all events")
		if _helper.contains_runtime_id_leak(ev):
			return harness.fail_result("manager replay event_log should not expose runtime ids")
		if ev.has("battle_seed") or ev.has("battle_rng_profile") or ev.has("speed_tie_roll") or ev.has("hit_roll") or ev.has("effect_roll") or ev.has("rng_stream_index"):
			return harness.fail_result("manager replay event_log should not expose private RNG fields")
		if String(ev.get("event_type", "")) == EventTypesScript.SYSTEM_BATTLE_HEADER:
			header_count += 1
			header_index = i
		if first_enter_index == -1 and String(ev.get("event_type", "")) == EventTypesScript.STATE_ENTER:
			first_enter_index = i
	if header_count != 1:
		return harness.fail_result("system:battle_header should appear exactly once")
	if first_enter_index == -1:
		return harness.fail_result("state:enter should exist")
	if not (header_index < first_enter_index):
		return harness.fail_result("system:battle_header must be earlier than first state:enter")
	return harness.pass_result()

func _test_header_snapshot_private_id_guard(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_unwrap = _unwrap_ok(manager.run_replay(harness.build_demo_replay_input(sample_factory, manager)), "run_replay")
	if not bool(replay_unwrap.get("ok", false)):
		return harness.fail_result(str(replay_unwrap.get("error", "manager run_replay failed")))
	var replay_output = replay_unwrap.get("data", {}).get("replay_output", null)
	if replay_output == null:
		return harness.fail_result("run_replay should return replay_output")
	var header_event = null
	for ev in replay_output.event_log:
		if ev is Dictionary and String(ev.get("event_type", "")) == EventTypesScript.SYSTEM_BATTLE_HEADER:
			header_event = ev
			break
	if header_event == null:
		return harness.fail_result("missing system:battle_header event")
	var header_snapshot = header_event.get("header_snapshot", null)
	if typeof(header_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("header_snapshot should be Dictionary")
	var required_fields: Array[String] = ["visibility_mode", "prebattle_public_teams", "initial_active_public_ids_by_side", "initial_field"]
	for field_name in required_fields:
		if not header_snapshot.has(field_name):
			return harness.fail_result("header_snapshot missing required field: %s" % field_name)
	if _helper.contains_private_instance_id_key(header_snapshot):
		return harness.fail_result("header_snapshot should not contain private instance IDs")
	return harness.pass_result()

func _test_replay_turn_timeline_matches_public_snapshot_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_unwrap = _unwrap_ok(manager.run_replay(harness.build_demo_replay_input(sample_factory, manager)), "run_replay")
	if not bool(replay_unwrap.get("ok", false)):
		return harness.fail_result(str(replay_unwrap.get("error", "manager run_replay failed")))
	var replay_payload: Dictionary = replay_unwrap.get("data", {})
	var replay_output = replay_payload.get("replay_output", null)
	if replay_output == null:
		return harness.fail_result("run_replay should return replay_output")
	if not (replay_output.turn_timeline is Array) or replay_output.turn_timeline.is_empty():
		return harness.fail_result("run_replay should expose non-empty turn_timeline")
	var initial_frame: Dictionary = replay_output.turn_timeline[0]
	if int(initial_frame.get("turn_index", -1)) != 0:
		return harness.fail_result("turn_timeline initial frame turn_index should be 0")
	var final_frame: Dictionary = replay_output.turn_timeline[replay_output.turn_timeline.size() - 1]
	var final_snapshot: Dictionary = final_frame.get("public_snapshot", {})
	var replay_snapshot: Dictionary = replay_payload.get("public_snapshot", {})
	if final_snapshot != replay_snapshot:
		return harness.fail_result("turn_timeline final public_snapshot should match manager replay public_snapshot")
	return harness.pass_result()

func _unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	if envelope == null:
		return {"ok": false, "error": "%s returned null envelope" % label}
	var required_keys := ["ok", "data", "error_code", "error_message"]
	for key in required_keys:
		if not envelope.has(key):
			return {"ok": false, "error": "%s missing envelope key: %s" % [label, key]}
	if bool(envelope.get("ok", false)):
		return {"ok": true, "data": envelope.get("data", null)}
	if envelope.get("data", null) != null:
		return {"ok": false, "error": "%s failure envelope must set data=null" % label}
	return {"ok": false, "error": "%s failed: %s (%s)" % [label, str(envelope.get("error_message", "")), str(envelope.get("error_code", ""))]}
