extends "res://tests/support/gdunit_suite_bridge.gd"

const BattleCoreManagerScript := preload("res://src/battle_core/facades/battle_core_manager.gd")
const BattleCoreManagerContainerServiceScript := preload("res://src/battle_core/facades/battle_core_manager_container_service.gd")
const BattleCorePublicSnapshotBuilderScript := preload("res://src/battle_core/facades/public_snapshot_builder.gd")
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
	extends BattleCoreManagerContainerServiceScript

	var invalid_session := InvalidRuntimeSession.new()

	func create_session_result(session_id: String, _init_payload: Dictionary) -> Dictionary:
		return {
			"ok": true,
			"data": {
				"session": invalid_session,
				"session_id": session_id,
			},
			"error_code": null,
			"error_message": null,
		}

class RecordingPublicSnapshotBuilder:
	extends BattleCorePublicSnapshotBuilderScript

	var build_calls: int = 0

	func build_public_snapshot(_battle_state: BattleState, _content_index: BattleContentIndex = null) -> Dictionary:
		build_calls += 1
		return {"should_not_escape": true}


func test_manager_invalid_session_read_contract() -> void:
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
	var init_result = manager.create_session({
		"battle_seed": 307,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": _harness.build_sample_setup(sample_factory),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		fail(str(close_unwrap.get("error", "manager close_session failed")))
		return
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
			fail(str(failure.get("error", "manager invalid session read contract failed")))
			return

func test_manager_run_turn_invalid_envelope_contract() -> void:
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
	var init_result = manager.create_session({
		"battle_seed": 308,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": _harness.build_sample_setup(sample_factory),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
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
		fail(str(failure.get("error", "manager run_turn invalid envelope contract failed")))
		return

func test_manager_unconfigured_dependency_guard_contract() -> void:
	var manager = BattleCoreManagerScript.new()
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 309,
			"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
			"battle_setup": _harness.build_sample_setup(sample_factory),
		}),
		"create_session",
		ErrorCodesScript.INVALID_COMPOSITION,
		"missing dependency"
	)
	if not bool(failure.get("ok", false)):
		fail(str(failure.get("error", "manager unconfigured dependency guard contract failed")))
		return

func test_manager_create_session_empty_snapshot_paths_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 3091,
			"content_snapshot_paths": PackedStringArray(),
			"battle_setup": _harness.build_sample_setup(sample_factory),
		}),
		"create_session",
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"non-empty content_snapshot_paths"
	)
	if not bool(failure.get("ok", false)):
		fail(str(failure.get("error", "manager create_session empty snapshot paths contract failed")))
		return

func test_manager_create_session_invalid_battle_setup_type_contract() -> void:
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
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 30915,
			"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
			"battle_setup": 123,
		}),
		"create_session",
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"requires battle_setup.sides"
	)
	if not bool(failure.get("ok", false)):
		fail(str(failure.get("error", "manager create_session invalid battle_setup type contract failed")))
		return

func test_manager_create_session_invalid_side_id_contract() -> void:
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
	var cases: Array = [
		{"p1_side_id": "", "p2_side_id": "P2", "needle": "battle_setup.sides[0].side_id to be non-empty"},
		{"p1_side_id": "P1", "p2_side_id": "P1", "needle": "duplicated battle_setup side_id: P1"},
	]
	for test_case in cases:
		var battle_setup = _harness.build_sample_setup(sample_factory)
		battle_setup.sides[0].side_id = String(test_case["p1_side_id"])
		battle_setup.sides[1].side_id = String(test_case["p2_side_id"])
		var failure = _helper.expect_failure_code(
			manager.create_session({
				"battle_seed": 3092,
				"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
				"battle_setup": battle_setup,
			}),
			"create_session",
			ErrorCodesScript.INVALID_MANAGER_REQUEST,
			String(test_case["needle"])
		)
		if not bool(failure.get("ok", false)):
			fail(str(failure.get("error", "manager create_session invalid side_id contract failed")))
			return

func test_manager_event_log_negative_from_index_contract() -> void:
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
		"battle_seed": 310,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": _harness.build_sample_setup(sample_factory),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var failure = _helper.expect_failure_code(
		manager.get_event_log_snapshot(session_id, -1),
		"get_event_log_snapshot",
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"from_index >= 0"
	)
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		fail(str(close_unwrap.get("error", "manager close_session failed")))
		return
	if not bool(failure.get("ok", false)):
		fail(str(failure.get("error", "manager event log negative from_index contract failed")))
		return

func test_manager_disposed_request_guard_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	manager.dispose()
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 311,
			"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
			"battle_setup": _harness.build_sample_setup(sample_factory),
		}),
		"create_session_after_dispose",
		ErrorCodesScript.INVALID_MANAGER_REQUEST,
		"BattleCoreManager is disposed"
	)
	if not bool(failure.get("ok", false)):
		fail(str(failure.get("error", "disposed manager guard contract failed")))
		return

func test_manager_create_session_runtime_guard_contract() -> void:
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
	var stub_container_service := InvalidRuntimeContainerService.new()
	var stub_public_snapshot_builder := RecordingPublicSnapshotBuilder.new()
	manager._container_service = stub_container_service
	manager._public_snapshot_builder = stub_public_snapshot_builder
	var failure = _helper.expect_failure_code(
		manager.create_session({
			"battle_seed": 312,
			"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
			"battle_setup": _harness.build_sample_setup(sample_factory),
		}),
		"create_session",
		ErrorCodesScript.INVALID_STATE_CORRUPTION,
		"runtime state invalid"
	)
	if not bool(failure.get("ok", false)):
		fail(str(failure.get("error", "create_session runtime guard contract failed")))
		return
	var active_count_unwrap = _helper.unwrap_ok(manager.active_session_count(), "active_session_count")
	if not bool(active_count_unwrap.get("ok", false)):
		fail(str(active_count_unwrap.get("error", "manager active_session_count failed")))
		return
	if int(active_count_unwrap.get("data", {}).get("count", -1)) != 0:
		fail("create_session runtime guard should not retain invalid session")
		return
	if not stub_container_service.invalid_session.disposed:
		fail("create_session runtime guard should dispose the invalid session before returning")
		return
	if stub_public_snapshot_builder.build_calls != 0:
		fail("create_session runtime guard must fail before manager projects the first public snapshot")
		return

