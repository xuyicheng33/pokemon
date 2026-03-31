extends RefCounted
class_name GojoSuite

const GojoSetupAndMarkersSuiteScript := preload("res://tests/suites/gojo_setup_and_markers_suite.gd")
const GojoSnapshotSuiteScript := preload("res://tests/suites/gojo_snapshot_suite.gd")
const GojoMurasakiSuiteScript := preload("res://tests/suites/gojo_murasaki_suite.gd")
const GojoDomainSuiteScript := preload("res://tests/suites/gojo_domain_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    GojoSetupAndMarkersSuiteScript.new().register_tests(runner, failures, harness)
    GojoSnapshotSuiteScript.new().register_tests(runner, failures, harness)
    GojoMurasakiSuiteScript.new().register_tests(runner, failures, harness)
    GojoDomainSuiteScript.new().register_tests(runner, failures, harness)
