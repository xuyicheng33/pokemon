extends RefCounted
class_name ContentLoggingSuite

const LogCauseContractSuiteScript := preload("res://tests/suites/log_cause_contract_suite.gd")
const ContentValidationContractSuiteScript := preload("res://tests/suites/content_validation_contract_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	LogCauseContractSuiteScript.new().register_tests(runner, failures, harness)
	ContentValidationContractSuiteScript.new().register_tests(runner, failures, harness)
