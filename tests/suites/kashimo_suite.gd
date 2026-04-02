extends RefCounted
class_name KashimoSuite

const KashimoSnapshotSuiteScript := preload("res://tests/suites/kashimo_snapshot_suite.gd")
const KashimoRuntimeSuiteScript := preload("res://tests/suites/kashimo_runtime_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    KashimoSnapshotSuiteScript.new().register_tests(runner, failures, harness)
    KashimoRuntimeSuiteScript.new().register_tests(runner, failures, harness)
