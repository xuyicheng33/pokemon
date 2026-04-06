extends RefCounted

const BattleCoreManagerScript := preload("res://src/battle_core/facades/battle_core_manager.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

class InvalidRuntimeSession:
	extends RefCounted

	var disposed: bool = false

	func validate_runtime_result() -> Dictionary:
		return {
			"ok": false,
			"data": null,
			"error_code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"error_message": "BattleCoreManager runtime state invalid: %s" % ErrorCodesScript.INVALID_STATE_CORRUPTION,
		}

	func dispose() -> void:
		disposed = true

class InvalidRuntimeContainerService:
	extends RefCounted

	var container_factory: Callable = Callable()
	var public_snapshot_builder = null
	var container_factory_owner = null
	var invalid_session := InvalidRuntimeSession.new()

	func create_session_result(session_id: String, _init_payload: Dictionary) -> Dictionary:
		return {
			"session": invalid_session,
			"response": {
				"ok": true,
				"data": {
					"session_id": session_id,
					"public_snapshot": {"should_not_escape": true},
					"prebattle_public_teams": [],
				},
				"error_code": null,
				"error_message": null,
				},
			}

class RecordingPublicSnapshotBuilder:
	extends RefCounted

	var build_calls: int = 0

	func build_public_snapshot(_battle_state, _content_index) -> Dictionary:
		build_calls += 1
		return {"should_not_escape": true}

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("manager_invalid_session_read_contract", failures, Callable(self, "_test_manager_invalid_session_read_contract").bind(harness))
	runner.run_test("manager_run_turn_invalid_envelope_contract", failures, Callable(self, "_test_manager_run_turn_invalid_envelope_contract").bind(harness))
	runner.run_test("manager_unconfigured_dependency_guard_contract", failures, Callable(self, "_test_manager_unconfigured_dependency_guard_contract").bind(harness))
	runner.run_test("manager_create_session_empty_snapshot_paths_contract", failures, Callable(self, "_test_manager_create_session_empty_snapshot_paths_contract").bind(harness))
	runner.run_test("manager_event_log_negative_from_index_contract", failures, Callable(self, "_test_manager_event_log_negative_from_index_contract").bind(harness))
	runner.run_test("manager_disposed_request_guard_contract", failures, Callable(self, "_test_manager_disposed_request_guard_contract").bind(harness))
	runner.run_test("manager_create_session_runtime_guard_contract", failures, Callable(self, "_test_manager_create_session_runtime_guard_contract").bind(harness))

func _test_manager_invalid_session_read_contract(harness) -> Dictionary:
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
	var init_result = manager.create_session({
		"battle_seed": 307,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": harness.build_sample_setup(sample_factory),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	var checks := [
		{"label": "get_legal_actions", "envelope": manager.get_legal_actions(session_id, "P1")},
		{"label": "get_public_snapshot", "envelope": manager.get_public_snapshot(session_id)},
		{"label": "get_event_log_snapshot", "envelope": manager.get_event_log_snapshot(session_id)},
		{"label": "run_turn", "envelope": manager.run_turn(session_id, [])},
	]
	for check in checks:
		var failure = _helper.expect_failure_code(
			check["envelope"],
			String(check.get("label", "")),
			ErrorCodesScript.INVALID_SESSION,
			"unknown battle session"
		)
		if not bool(failure.get("ok", false)):
			return harness.fail_result(str(failure.get("error", "manager invalid session read contract failed")))
	return harness.pass_result()

func _test_manager_run_turn_invalid_envelope_contract(harness) -> Dictionary:
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
	var init_result = manager.create_session({
		"battle_seed": 308,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": harness.build_sample_setup(sample_factory),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id: String = str(init_unwrap.get("data", {}).get("session_id", ""))
	var failure = _helper.expect_failure_code(
		manager.run_turn(session_id, [
			manager.build_command({
				"turn_index": 1,
				"command_type": CommandTypesScript.SKILL,
				"command_source": "manual",
				"side_id": "P1",
				"actor_public_id": "P1-A",
				"skill_id": "missing_skill_definition",
			}),
			manager.build_command({
				"turn_index": 1,
				"command_type": CommandTypesScript.WAIT,
				"command_source": "manual",
				"side_id": "P2",
				"actor_public_id": "P2-A",
			}),
		]),
		"run_turn",
		ErrorCodesScript.INVALID_COMMAND_PAYLOAD
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_turn invalid envelope contract failed")))
	return harness.pass_result()

func _test_manager_unconfigured_dependency_guard_contract(harness) -> Dictionary:
	var manager = BattleCoreManagerScript.new()
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 309,
			"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
			"battle_setup": harness.build_sample_setup(sample_factory),
		}),
		"create_session",
		ErrorCodesScript.INVALID_COMPOSITION,
		"missing dependency"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager unconfigured dependency guard contract failed")))
	return harness.pass_result()

func _test_manager_create_session_empty_snapshot_paths_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 3091,
			"content_snapshot_paths": PackedStringArray(),
			"battle_setup": harness.build_sample_setup(sample_factory),
		}),
		"create_session",
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"non-empty content_snapshot_paths"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager create_session empty snapshot paths contract failed")))
	return harness.pass_result()

func _test_manager_event_log_negative_from_index_contract(harness) -> Dictionary:
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
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 310,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": harness.build_sample_setup(sample_factory),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var failure = _helper.expect_failure_code(
		manager.get_event_log_snapshot(session_id, -1),
		"get_event_log_snapshot",
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"from_index >= 0"
	)
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager event log negative from_index contract failed")))
	return harness.pass_result()

func _test_manager_disposed_request_guard_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	manager.dispose()
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 311,
			"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
			"battle_setup": harness.build_sample_setup(sample_factory),
		}),
		"create_session_after_dispose",
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"BattleCoreManager is disposed"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "disposed manager guard contract failed")))
	return harness.pass_result()

func _test_manager_create_session_runtime_guard_contract(harness) -> Dictionary:
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
	var stub_container_service := InvalidRuntimeContainerService.new()
	var stub_public_snapshot_builder := RecordingPublicSnapshotBuilder.new()
	manager._container_service = stub_container_service
	manager._public_snapshot_builder = stub_public_snapshot_builder
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 312,
			"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
			"battle_setup": harness.build_sample_setup(sample_factory),
		}),
		"create_session",
		ErrorCodesScript.INVALID_STATE_CORRUPTION,
		"runtime state invalid"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "create_session runtime guard contract failed")))
	var active_count_unwrap = _helper.unwrap_ok(manager.active_session_count(), "active_session_count")
	if not bool(active_count_unwrap.get("ok", false)):
		return harness.fail_result(str(active_count_unwrap.get("error", "manager active_session_count failed")))
	if int(active_count_unwrap.get("data", {}).get("count", -1)) != 0:
		return harness.fail_result("create_session runtime guard should not retain invalid session")
	if not stub_container_service.invalid_session.disposed:
		return harness.fail_result("create_session runtime guard should dispose the invalid session before returning")
	if stub_public_snapshot_builder.build_calls != 0:
		return harness.fail_result("create_session runtime guard must fail before manager projects the first public snapshot")
	return harness.pass_result()
