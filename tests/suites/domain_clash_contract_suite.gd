extends RefCounted
class_name DomainClashContractSuite

const DomainClashResolutionSuiteScript := preload("res://tests/suites/domain_clash_resolution_suite.gd")
const DomainClashGuardSuiteScript := preload("res://tests/suites/domain_clash_guard_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	DomainClashResolutionSuiteScript.new().register_tests(runner, failures, harness)
	DomainClashGuardSuiteScript.new().register_tests(runner, failures, harness)
