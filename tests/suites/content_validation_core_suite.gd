extends RefCounted
class_name ContentValidationCoreSuite

# 入口 wrapper；断言本体下沉到 content_validation_core/ 子目录。
const ContentValidationBaseSnapshotSuiteScript := preload("res://tests/suites/content_validation_core/snapshot_constraints_suite.gd")
const ContentValidationSetupSuiteScript := preload("res://tests/suites/content_validation_core/setup_runtime_suite.gd")
const ContentValidationFormalRegistrySuiteScript := preload("res://tests/suites/content_validation_core/formal_registry_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    ContentValidationBaseSnapshotSuiteScript.new().register_tests(runner, failures, harness)
    ContentValidationSetupSuiteScript.new().register_tests(runner, failures, harness)
    ContentValidationFormalRegistrySuiteScript.new().register_tests(runner, failures, harness)
