extends RefCounted
class_name ManagerPublicContractSuite

const ManagerSnapshotPublicContractSuiteScript := preload("res://tests/suites/manager_snapshot_public_contract_suite.gd")
const ManagerLogAndRuntimeContractSuiteScript := preload("res://tests/suites/manager_log_and_runtime_contract_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	ManagerSnapshotPublicContractSuiteScript.new().register_tests(runner, failures, harness)
	ManagerLogAndRuntimeContractSuiteScript.new().register_tests(runner, failures, harness)
