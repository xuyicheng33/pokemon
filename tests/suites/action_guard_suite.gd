extends RefCounted
class_name ActionGuardSuite

const ActionGuardActionFlowSuiteScript := preload("res://tests/suites/action_guard_action_flow_suite.gd")
const ActionGuardCommandPayloadSuiteScript := preload("res://tests/suites/action_guard_command_payload_suite.gd")
const ActionGuardStateIntegritySuiteScript := preload("res://tests/suites/action_guard_state_integrity_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	ActionGuardActionFlowSuiteScript.new().register_tests(runner, failures, harness)
	ActionGuardCommandPayloadSuiteScript.new().register_tests(runner, failures, harness)
	ActionGuardStateIntegritySuiteScript.new().register_tests(runner, failures, harness)
