extends RefCounted
class_name ReplayTurnSuite

const ReplayDeterminismSuiteScript := preload("res://tests/suites/replay_determinism_suite.gd")
const SelectionTimeoutAndWaitSuiteScript := preload("res://tests/suites/selection_timeout_and_wait_suite.gd")
const ReplayContentSmokeSuiteScript := preload("res://tests/suites/replay_content_smoke_suite.gd")
const InitMatchupLifecycleSuiteScript := preload("res://tests/suites/init_matchup_lifecycle_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	ReplayDeterminismSuiteScript.new().register_tests(runner, failures, harness)
	SelectionTimeoutAndWaitSuiteScript.new().register_tests(runner, failures, harness)
	ReplayContentSmokeSuiteScript.new().register_tests(runner, failures, harness)
	InitMatchupLifecycleSuiteScript.new().register_tests(runner, failures, harness)
