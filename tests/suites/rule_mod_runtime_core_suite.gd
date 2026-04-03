extends RefCounted
class_name RuleModRuntimeCoreSuite

const RuleModRuntimeCorePathsSuiteScript := preload("res://tests/suites/rule_mod_runtime_core_paths_suite.gd")
const RuleModRuntimeExtensionSuiteScript := preload("res://tests/suites/rule_mod_runtime_extension_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    RuleModRuntimeCorePathsSuiteScript.new().register_tests(runner, failures, harness)
    RuleModRuntimeExtensionSuiteScript.new().register_tests(runner, failures, harness)
