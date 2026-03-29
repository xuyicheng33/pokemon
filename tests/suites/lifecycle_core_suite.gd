extends RefCounted
class_name LifecycleCoreSuite

const LifecycleTurnScopeSuiteScript := preload("res://tests/suites/lifecycle_turn_scope_suite.gd")
const LifecycleReplacementFlowSuiteScript := preload("res://tests/suites/lifecycle_replacement_flow_suite.gd")
const LifecycleFieldBreakSuiteScript := preload("res://tests/suites/lifecycle_field_break_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    LifecycleTurnScopeSuiteScript.new().register_tests(runner, failures, harness)
    LifecycleReplacementFlowSuiteScript.new().register_tests(runner, failures, harness)
    LifecycleFieldBreakSuiteScript.new().register_tests(runner, failures, harness)
