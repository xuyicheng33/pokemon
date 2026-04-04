extends RefCounted
class_name ManagerFacadeInternalContractSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("manager_uses_session_internal_facade_contract", failures, Callable(self, "_test_manager_uses_session_internal_facade_contract").bind(harness))

func _test_manager_uses_session_internal_facade_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 1300,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": sample_factory.build_sample_setup(),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	if session_id.is_empty():
		return harness.fail_result("create_session should return session_id")
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("manager should route legal action lookup through session facade")
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
		return harness.fail_result(str(turn_result_unwrap.get("error", "manager run_turn failed")))
	var turn_data: Dictionary = turn_result_unwrap.get("data", {})
	if String(turn_data.get("session_id", "")) != session_id:
		return harness.fail_result("manager run_turn should preserve session_id in public envelope")
	var public_snapshot: Dictionary = turn_data.get("public_snapshot", {})
	var shape_error := _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("manager run_turn should keep returning manager-built public_snapshot: %s" % shape_error)
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var event_log_data: Dictionary = event_log_unwrap.get("data", {})
	if typeof(event_log_data.get("events", null)) != TYPE_ARRAY:
		return harness.fail_result("manager should route event log reads through session facade")
	if int(event_log_data.get("total_size", -1)) < 0:
		return harness.fail_result("manager event log snapshot should expose non-negative total_size")
	return harness.pass_result()
