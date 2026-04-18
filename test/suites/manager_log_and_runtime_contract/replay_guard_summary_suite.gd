extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared.gd"

func test_manager_container_run_replay_failed_output_contract() -> void:
	_assert_legacy_result(_test_manager_container_run_replay_failed_output_contract())

func test_replay_output_helper_runtime_fault_contract() -> void:
	_assert_legacy_result(_test_replay_output_helper_runtime_fault_contract())

func test_replay_output_helper_logger_fault_contract() -> void:
	_assert_legacy_result(_test_replay_output_helper_logger_fault_contract())

func test_log_event_builder_missing_chain_context_contract() -> void:
	_assert_legacy_result(_test_log_event_builder_missing_chain_context_contract())

func test_log_event_builder_missing_cause_event_id_contract() -> void:
	_assert_legacy_result(_test_log_event_builder_missing_cause_event_id_contract())
