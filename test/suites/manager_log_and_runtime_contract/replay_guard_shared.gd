extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared_base.gd"

const ReplayGuardInputSharedScript := preload("res://test/suites/manager_log_and_runtime_contract/replay_guard_input_shared.gd")
const ReplayGuardSummarySharedScript := preload("res://test/suites/manager_log_and_runtime_contract/replay_guard_summary_shared.gd")
const ReplayGuardFailureSharedScript := preload("res://test/suites/manager_log_and_runtime_contract/replay_guard_failure_shared.gd")

func _test_manager_run_replay_empty_snapshot_paths_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardInputSharedScript, "_test_manager_run_replay_empty_snapshot_paths_contract", [harness])

func _test_manager_run_replay_invalid_input_type_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardInputSharedScript, "_test_manager_run_replay_invalid_input_type_contract", [harness])

func _test_manager_run_replay_null_command_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardInputSharedScript, "_test_manager_run_replay_null_command_contract", [harness])

func _test_manager_run_replay_invalid_side_id_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardInputSharedScript, "_test_manager_run_replay_invalid_side_id_contract", [harness])

func _test_manager_run_replay_unconsumed_future_command_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardInputSharedScript, "_test_manager_run_replay_unconsumed_future_command_contract", [harness])

func _test_manager_container_run_replay_failed_output_contract() -> Dictionary:
	return _call_helper(ReplayGuardSummarySharedScript, "_test_manager_container_run_replay_failed_output_contract")

func _test_manager_container_run_replay_missing_dependency_contract() -> Dictionary:
	return _call_helper(ReplayGuardSummarySharedScript, "_test_manager_container_run_replay_missing_dependency_contract")

func _test_replay_output_helper_runtime_fault_contract() -> Dictionary:
	return _call_helper(ReplayGuardSummarySharedScript, "_test_replay_output_helper_runtime_fault_contract")

func _test_replay_output_helper_logger_fault_contract() -> Dictionary:
	return _call_helper(ReplayGuardSummarySharedScript, "_test_replay_output_helper_logger_fault_contract")

func _test_log_event_builder_missing_chain_context_contract() -> Dictionary:
	return _call_helper(ReplayGuardSummarySharedScript, "_test_log_event_builder_missing_chain_context_contract")

func _test_log_event_builder_missing_cause_event_id_contract() -> Dictionary:
	return _call_helper(ReplayGuardSummarySharedScript, "_test_log_event_builder_missing_cause_event_id_contract")

func _test_turn_selection_resolver_legal_action_service_failure_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardFailureSharedScript, "_test_turn_selection_resolver_legal_action_service_failure_contract", [harness])

func _test_turn_selection_resolver_failure_is_atomic_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardFailureSharedScript, "_test_turn_selection_resolver_failure_is_atomic_contract", [harness])

func _test_turn_selection_resolver_command_builder_failure_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardFailureSharedScript, "_test_turn_selection_resolver_command_builder_failure_contract", [harness])

func _test_legal_action_service_rule_mod_failure_contract(harness) -> Dictionary:
	return _call_helper(ReplayGuardFailureSharedScript, "_test_legal_action_service_rule_mod_failure_contract", [harness])

func _call_helper(script_ref, method_name: String, args: Array = []) -> Dictionary:
	var helper = script_ref.new()
	var result: Dictionary = helper.callv(method_name, args)
	helper.free()
	return result
