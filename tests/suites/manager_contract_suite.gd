extends RefCounted
class_name ManagerContractSuite

const ManagerPublicContractSuiteScript := preload("res://tests/suites/manager_public_contract_suite.gd")
const ManagerSessionIsolationSuiteScript := preload("res://tests/suites/manager_session_isolation_suite.gd")
const ManagerReplayHeaderContractSuiteScript := preload("res://tests/suites/manager_replay_header_contract_suite.gd")
const ContentSnapshotCacheSuiteScript := preload("res://tests/suites/content_snapshot_cache_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	ManagerPublicContractSuiteScript.new().register_tests(runner, failures, harness)
	ManagerSessionIsolationSuiteScript.new().register_tests(runner, failures, harness)
	ManagerReplayHeaderContractSuiteScript.new().register_tests(runner, failures, harness)
	ContentSnapshotCacheSuiteScript.new().register_tests(runner, failures, harness)
