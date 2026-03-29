extends RefCounted
class_name SukunaSuite

const SukunaSetupRegenSuiteScript := preload("res://tests/suites/sukuna_setup_regen_suite.gd")
const SukunaKamadoDomainSuiteScript := preload("res://tests/suites/sukuna_kamado_domain_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    SukunaSetupRegenSuiteScript.new().register_tests(runner, failures, harness)
    SukunaKamadoDomainSuiteScript.new().register_tests(runner, failures, harness)
