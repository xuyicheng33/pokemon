extends RefCounted
class_name UltimateFieldSuite

const UltimatePointsContractSuiteScript := preload("res://tests/suites/ultimate_points_contract_suite.gd")
const DomainClashContractSuiteScript := preload("res://tests/suites/domain_clash_contract_suite.gd")
const FieldLifecycleContractSuiteScript := preload("res://tests/suites/field_lifecycle_contract_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	UltimatePointsContractSuiteScript.new().register_tests(runner, failures, harness)
	DomainClashContractSuiteScript.new().register_tests(runner, failures, harness)
	FieldLifecycleContractSuiteScript.new().register_tests(runner, failures, harness)
