extends RefCounted
class_name ActionGuardStateIntegritySuite

const ActionGuardChainDepthSuiteScript := preload("res://tests/suites/action_guard_chain_depth_suite.gd")
const ActionGuardInvalidRuntimeSuiteScript := preload("res://tests/suites/action_guard_invalid_runtime_suite.gd")
const ActionGuardExpireFailureSuiteScript := preload("res://tests/suites/action_guard_expire_failure_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	ActionGuardChainDepthSuiteScript.new().register_tests(runner, failures, harness)
	ActionGuardInvalidRuntimeSuiteScript.new().register_tests(runner, failures, harness)
	ActionGuardExpireFailureSuiteScript.new().register_tests(runner, failures, harness)
