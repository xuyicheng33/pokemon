extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared.gd"

func test_manager_run_replay_empty_snapshot_paths_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_empty_snapshot_paths_contract(_harness))

func test_manager_run_replay_invalid_input_type_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_invalid_input_type_contract(_harness))

func test_manager_run_replay_null_command_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_null_command_contract(_harness))

func test_manager_run_replay_invalid_side_id_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_invalid_side_id_contract(_harness))

func test_manager_run_replay_unconsumed_future_command_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_unconsumed_future_command_contract(_harness))
