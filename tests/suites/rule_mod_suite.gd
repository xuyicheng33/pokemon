extends RefCounted
class_name RuleModSuite

const RuleModRuntimeSuiteScript := preload("res://tests/suites/rule_mod_runtime_suite.gd")
const RuleModGuardSuiteScript := preload("res://tests/suites/rule_mod_guard_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    RuleModRuntimeSuiteScript.new().register_tests(runner, failures, harness)
    RuleModGuardSuiteScript.new().register_tests(runner, failures, harness)
