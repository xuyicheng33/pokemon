extends RefCounted
class_name ExtensionContractSuite

const ExtensionValidationContractSuiteScript := preload("res://tests/suites/extension_validation_contract_suite.gd")
const ActionLegalityContractSuiteScript := preload("res://tests/suites/action_legality_contract_suite.gd")
const ExtensionTargetingAccuracySuiteScript := preload("res://tests/suites/extension_targeting_accuracy_suite.gd")
const RemoveEffectAmbiguitySuiteScript := preload("res://tests/suites/remove_effect_ambiguity_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    ExtensionValidationContractSuiteScript.new().register_tests(runner, failures, harness)
    ActionLegalityContractSuiteScript.new().register_tests(runner, failures, harness)
    ExtensionTargetingAccuracySuiteScript.new().register_tests(runner, failures, harness)
    RemoveEffectAmbiguitySuiteScript.new().register_tests(runner, failures, harness)
