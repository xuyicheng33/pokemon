extends RefCounted

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("manager_run_replay_empty_snapshot_paths_contract", failures, Callable(self, "_test_manager_run_replay_empty_snapshot_paths_contract").bind(harness))
	runner.run_test("manager_run_replay_null_command_contract", failures, Callable(self, "_test_manager_run_replay_null_command_contract").bind(harness))

func _test_manager_run_replay_empty_snapshot_paths_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = sample_factory.build_demo_replay_input(manager)
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
	replay_input.battle_setup = sample_factory.build_sample_setup()
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
