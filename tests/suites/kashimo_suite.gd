extends RefCounted
class_name KashimoSuite

const KashimoSnapshotSuiteScript := preload("res://tests/suites/kashimo_snapshot_suite.gd")
const KashimoRuntimeSuiteScript := preload("res://tests/suites/kashimo_runtime_suite.gd")
const KashimoChargeLifecycleSuiteScript := preload("res://tests/suites/kashimo_charge_lifecycle_suite.gd")
const KashimoSetupLoadoutSuiteScript := preload("res://tests/suites/kashimo_setup_loadout_suite.gd")
const KashimoAmberSuiteScript := preload("res://tests/suites/kashimo_amber_suite.gd")
const KashimoManagerSmokeSuiteScript := preload("res://tests/suites/kashimo_manager_smoke_suite.gd")
const KashimoManagerBlackboxSuiteScript := preload("res://tests/suites/kashimo_manager_blackbox_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    KashimoSnapshotSuiteScript.new().register_tests(runner, failures, harness)
    KashimoRuntimeSuiteScript.new().register_tests(runner, failures, harness)
    KashimoChargeLifecycleSuiteScript.new().register_tests(runner, failures, harness)
    KashimoSetupLoadoutSuiteScript.new().register_tests(runner, failures, harness)
    KashimoAmberSuiteScript.new().register_tests(runner, failures, harness)
    KashimoManagerSmokeSuiteScript.new().register_tests(runner, failures, harness)
    KashimoManagerBlackboxSuiteScript.new().register_tests(runner, failures, harness)
