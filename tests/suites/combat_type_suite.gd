extends RefCounted
class_name CombatTypeSuite

const CombatTypeDefinitionSuiteScript := preload("res://tests/suites/combat_type_definition_suite.gd")
const CombatTypeRuntimeSuiteScript := preload("res://tests/suites/combat_type_runtime_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    CombatTypeDefinitionSuiteScript.new().register_tests(runner, failures, harness)
    CombatTypeRuntimeSuiteScript.new().register_tests(runner, failures, harness)
