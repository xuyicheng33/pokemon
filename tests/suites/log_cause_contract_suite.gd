extends RefCounted
class_name LogCauseContractSuite

const LogCauseSemanticsSuiteScript := preload("res://tests/suites/log_cause_semantics_suite.gd")
const LogCauseAnchorSuiteScript := preload("res://tests/suites/log_cause_anchor_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    LogCauseSemanticsSuiteScript.new().register_tests(runner, failures, harness)
    LogCauseAnchorSuiteScript.new().register_tests(runner, failures, harness)
