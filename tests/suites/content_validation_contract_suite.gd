extends RefCounted
class_name ContentValidationContractSuite

const ContentValidationCoreSuiteScript := preload("res://tests/suites/content_validation_core_suite.gd")
const ContentValidationDomainSuiteScript := preload("res://tests/suites/content_validation_domain_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	ContentValidationCoreSuiteScript.new().register_tests(runner, failures, harness)
	ContentValidationDomainSuiteScript.new().register_tests(runner, failures, harness)
