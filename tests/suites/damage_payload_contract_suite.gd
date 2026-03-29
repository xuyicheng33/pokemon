extends RefCounted
class_name DamagePayloadContractSuite

const DamagePayloadValidationSuiteScript := preload("res://tests/suites/damage_payload_validation_suite.gd")
const DamagePayloadFormulaResolutionSuiteScript := preload("res://tests/suites/damage_payload_formula_resolution_suite.gd")
const DamagePayloadFixedHealSuiteScript := preload("res://tests/suites/damage_payload_fixed_heal_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    DamagePayloadValidationSuiteScript.new().register_tests(runner, failures, harness)
    DamagePayloadFormulaResolutionSuiteScript.new().register_tests(runner, failures, harness)
    DamagePayloadFixedHealSuiteScript.new().register_tests(runner, failures, harness)
