extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared_base.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func _test_manager_run_replay_empty_snapshot_paths_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = harness.build_demo_replay_input(sample_factory, manager)
	if replay_input == null:
		return harness.fail_result("demo replay input build failed")
	replay_input.content_snapshot_paths = PackedStringArray()
	var failure = _helper.expect_failure_code(
		manager.run_replay(replay_input),
		"run_replay",
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"non-empty content_snapshot_paths"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_replay empty snapshot paths contract failed")))
	return harness.pass_result()

func _test_manager_run_replay_invalid_input_type_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var failure = _helper.expect_failure_code(
		manager.run_replay(123),
		"run_replay",
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"requires battle_setup"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_replay invalid input type contract failed")))
	return harness.pass_result()

func _test_manager_run_replay_null_command_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 3092
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = harness.build_sample_setup(sample_factory)
	replay_input.command_stream = [null]
	var failure = _helper.expect_failure_code(
		manager.run_replay(replay_input),
		"run_replay",
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"command_stream[0] must not be null"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_replay null command contract failed")))
	return harness.pass_result()

func _test_manager_run_replay_invalid_side_id_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var cases: Array = [
		{"p1_side_id": "", "p2_side_id": "P2", "needle": "battle_setup.sides[0].side_id to be non-empty"},
		{"p1_side_id": "P1", "p2_side_id": "P1", "needle": "duplicated battle_setup side_id: P1"},
	]
	for test_case in cases:
		var replay_input = harness.build_demo_replay_input(sample_factory, manager)
		if replay_input == null:
			return harness.fail_result("demo replay input build failed")
		replay_input.battle_setup.sides[0].side_id = String(test_case["p1_side_id"])
		replay_input.battle_setup.sides[1].side_id = String(test_case["p2_side_id"])
		var failure = _helper.expect_failure_code(
			manager.run_replay(replay_input),
			"run_replay",
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			String(test_case["needle"])
		)
		if not bool(failure.get("ok", false)):
			return harness.fail_result(str(failure.get("error", "manager run_replay invalid side_id contract failed")))
	return harness.pass_result()

func _test_manager_run_replay_unconsumed_future_command_contract(harness) -> Dictionary:
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
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 3093
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = harness.build_sample_setup(sample_factory)
	replay_input.command_stream = [
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SURRENDER,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}).get("data", null),
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}).get("data", null),
		manager.build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}).get("data", null),
	]
	var failure = _helper.expect_failure_code(
		manager.run_replay(replay_input),
		"run_replay",
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"unconsumed command turn_index values"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_replay unconsumed future command contract failed")))
	return harness.pass_result()
