extends RefCounted
class_name ObitoSuite

const ObitoSnapshotSuiteScript := preload("res://tests/suites/obito_snapshot_suite.gd")
const ObitoRuntimePassiveAndSealSuiteScript := preload("res://tests/suites/obito_runtime_passive_and_seal_suite.gd")
const ObitoRuntimeYinyangSuiteScript := preload("res://tests/suites/obito_runtime_yinyang_suite.gd")
const ObitoRuntimeQiudaoYuSuiteScript := preload("res://tests/suites/obito_runtime_qiudaoyu_suite.gd")
const ObitoUltimateSuiteScript := preload("res://tests/suites/obito_ultimate_suite.gd")
const ObitoManagerSmokeSuiteScript := preload("res://tests/suites/obito_manager_smoke_suite.gd")
const ObitoManagerBlackboxSuiteScript := preload("res://tests/suites/obito_manager_blackbox_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    ObitoSnapshotSuiteScript.new().register_tests(runner, failures, harness)
    ObitoRuntimePassiveAndSealSuiteScript.new().register_tests(runner, failures, harness)
    ObitoRuntimeYinyangSuiteScript.new().register_tests(runner, failures, harness)
    ObitoRuntimeQiudaoYuSuiteScript.new().register_tests(runner, failures, harness)
    ObitoUltimateSuiteScript.new().register_tests(runner, failures, harness)
    ObitoManagerSmokeSuiteScript.new().register_tests(runner, failures, harness)
    ObitoManagerBlackboxSuiteScript.new().register_tests(runner, failures, harness)
