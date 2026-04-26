extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()


func test_manager_uses_session_internal_facade_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 1300,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": _harness.build_sample_setup(sample_factory),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	if session_id.is_empty():
		fail("create_session should return session_id")
		return
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		fail(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
		return
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		fail("manager should route legal action lookup through session facade")
		return
	var turn_result_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}),
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	]), "run_turn")
	if not bool(turn_result_unwrap.get("ok", false)):
		fail(str(turn_result_unwrap.get("error", "manager run_turn failed")))
		return
	var turn_data: Dictionary = turn_result_unwrap.get("data", {})
	if String(turn_data.get("session_id", "")) != session_id:
		fail("manager run_turn should preserve session_id in public envelope")
		return
	var public_snapshot: Dictionary = turn_data.get("public_snapshot", {})
	var shape_error := _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		fail("manager run_turn should keep returning manager-built public_snapshot: %s" % shape_error)
		return
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		fail(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
		return
	var event_log_data: Dictionary = event_log_unwrap.get("data", {})
	if typeof(event_log_data.get("events", null)) != TYPE_ARRAY:
		fail("manager should route event log reads through session facade")
		return
	if int(event_log_data.get("total_size", -1)) < 0:
		fail("manager event log snapshot should expose non-negative total_size")
		return
