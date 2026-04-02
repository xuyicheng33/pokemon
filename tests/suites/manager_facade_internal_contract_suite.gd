extends RefCounted
class_name ManagerFacadeInternalContractSuite

const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

class FakeBattleResult:
	extends RefCounted
	var finished := false
	var reason := ""

class FakeBattleState:
	extends RefCounted
	var battle_result = FakeBattleResult.new()

class FakePublicSnapshotBuilder:
	extends RefCounted
	func build_public_snapshot(_battle_state, _content_index) -> Dictionary:
		return {
			"battle_id": "fake_battle",
			"turn_index": 7,
			"sides": [],
			"field": {},
			"prebattle_public_teams": [],
		}

class FakeSession:
	extends RefCounted
	var container = null
	var battle_state = FakeBattleState.new()
	var content_index = {"source": "fake"}
	var runtime_validate_calls := 0
	var legal_action_calls := 0
	var run_turn_calls := 0
	var event_log_calls := 0
	var last_run_commands: Array = []

	func validate_runtime_result() -> Variant:
		runtime_validate_calls += 1
		return null

	func get_legal_actions_result(side_id: String) -> Dictionary:
		legal_action_calls += 1
		return {
			"ok": true,
			"data": {
				"actor_public_id": "P1-A",
				"requested_side_id": side_id,
			},
			"error_code": null,
			"error_message": null,
		}

	func run_turn_result(commands: Array) -> Dictionary:
		run_turn_calls += 1
		last_run_commands = commands.duplicate(true)
		return {
			"ok": true,
			"data": true,
			"error_code": null,
			"error_message": null,
		}

	func get_event_log_snapshot_result() -> Dictionary:
		event_log_calls += 1
		return {
			"ok": true,
			"data": [],
			"error_code": null,
			"error_message": null,
		}

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("manager_uses_session_internal_facade_contract", failures, Callable(self, "_test_manager_uses_session_internal_facade_contract").bind(harness))

func _test_manager_uses_session_internal_facade_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	manager.public_snapshot_builder = FakePublicSnapshotBuilder.new()

	var fake_session = FakeSession.new()
	manager._sessions["session_fake"] = fake_session

	var snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot("session_fake"), "get_public_snapshot")
	if not bool(snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var snapshot: Dictionary = snapshot_unwrap.get("data", {})
	if str(snapshot.get("battle_id", "")) != "fake_battle":
		return harness.fail_result("manager should keep using public_snapshot_builder without touching session.container")

	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions("session_fake", "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions: Dictionary = legal_actions_unwrap.get("data", {})
	if str(legal_actions.get("requested_side_id", "")) != "P1":
		return harness.fail_result("manager should route legal action lookup through session facade")

	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn("session_fake", [{"side_id": "P1"}, {"side_id": "P2"}]), "run_turn")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
	var turn_data: Dictionary = run_turn_unwrap.get("data", {})
	if str(turn_data.get("session_id", "")) != "session_fake":
		return harness.fail_result("run_turn should preserve session_id in public envelope")
	if str(turn_data.get("public_snapshot", {}).get("battle_id", "")) != "fake_battle":
		return harness.fail_result("run_turn should keep returning manager-built public_snapshot")

	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot("session_fake"), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var event_log_data: Dictionary = event_log_unwrap.get("data", {})
	if int(event_log_data.get("total_size", -1)) != 0:
		return harness.fail_result("manager should route event log reads through session facade")

	if fake_session.runtime_validate_calls != 4:
		return harness.fail_result("runtime validation should be delegated to session facade on every manager request")
	if fake_session.legal_action_calls != 1:
		return harness.fail_result("legal action lookup should be delegated to session facade")
	if fake_session.run_turn_calls != 1:
		return harness.fail_result("turn execution should be delegated to session facade")
	if fake_session.event_log_calls != 1:
		return harness.fail_result("event log snapshot should be delegated to session facade")
	if fake_session.last_run_commands.size() != 2:
		return harness.fail_result("manager should pass normalized commands into session facade")
	return harness.pass_result()
