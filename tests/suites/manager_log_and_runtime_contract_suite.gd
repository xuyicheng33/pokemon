extends RefCounted
class_name ManagerLogAndRuntimeContractSuite

const EventLogSuiteScript := preload("res://tests/suites/manager_log_and_runtime_contract/event_log_suite.gd")
const ReplayGuardSuiteScript := preload("res://tests/suites/manager_log_and_runtime_contract/replay_guard_suite.gd")
const SessionGuardSuiteScript := preload("res://tests/suites/manager_log_and_runtime_contract/session_guard_suite.gd")

var _event_log_suite = EventLogSuiteScript.new()
var _replay_guard_suite = ReplayGuardSuiteScript.new()
var _session_guard_suite = SessionGuardSuiteScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	_event_log_suite.register_tests(runner, failures, harness)
	_replay_guard_suite.register_tests(runner, failures, harness)
	_session_guard_suite.register_tests(runner, failures, harness)
