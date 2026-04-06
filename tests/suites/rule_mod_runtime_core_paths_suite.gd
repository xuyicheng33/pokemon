extends RefCounted
class_name RuleModRuntimeCorePathsSuite

const FieldScopeSuiteScript := preload("res://tests/suites/rule_mod_runtime_core_paths/field_scope_suite.gd")
const GroupingSuiteScript := preload("res://tests/suites/rule_mod_runtime_core_paths/grouping_suite.gd")
const RefreshSuiteScript := preload("res://tests/suites/rule_mod_runtime_core_paths/refresh_suite.gd")
const UnitScopeSuiteScript := preload("res://tests/suites/rule_mod_runtime_core_paths/unit_scope_suite.gd")

var _field_scope_suite = FieldScopeSuiteScript.new()
var _grouping_suite = GroupingSuiteScript.new()
var _refresh_suite = RefreshSuiteScript.new()
var _unit_scope_suite = UnitScopeSuiteScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	_unit_scope_suite.register_tests(runner, failures, harness)
	_field_scope_suite.register_tests(runner, failures, harness)
	_grouping_suite.register_tests(runner, failures, harness)
	_refresh_suite.register_tests(runner, failures, harness)
