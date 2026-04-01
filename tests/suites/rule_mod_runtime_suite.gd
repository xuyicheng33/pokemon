extends RefCounted
class_name RuleModRuntimeSuite

const RuleModRuntimeCoreSuiteScript := preload("res://tests/suites/rule_mod_runtime_core_suite.gd")
const RuleModRuntimeSchemaSuiteScript := preload("res://tests/suites/rule_mod_runtime_schema_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	RuleModRuntimeCoreSuiteScript.new().register_tests(runner, failures, harness)
	RuleModRuntimeSchemaSuiteScript.new().register_tests(runner, failures, harness)
