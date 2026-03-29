extends RefCounted
class_name ForcedReplaceSuite

const ForcedReplaceLifecycleSuiteScript := preload("res://tests/suites/forced_replace_lifecycle_suite.gd")
const ForcedReplaceFieldBreakSuiteScript := preload("res://tests/suites/forced_replace_field_break_suite.gd")
const ForcedReplaceInvalidSelectionSuiteScript := preload("res://tests/suites/forced_replace_invalid_selection_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    ForcedReplaceLifecycleSuiteScript.new().register_tests(runner, failures, harness)
    ForcedReplaceFieldBreakSuiteScript.new().register_tests(runner, failures, harness)
    ForcedReplaceInvalidSelectionSuiteScript.new().register_tests(runner, failures, harness)
