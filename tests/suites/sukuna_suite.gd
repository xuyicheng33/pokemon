extends RefCounted
class_name SukunaSuite

const SukunaSetupRegenSuiteScript := preload("res://tests/suites/sukuna_setup_regen_suite.gd")
const SukunaSnapshotSuiteScript := preload("res://tests/suites/sukuna_snapshot_suite.gd")
const SukunaKamadoSuiteScript := preload("res://tests/suites/sukuna_kamado_suite.gd")
const SukunaDomainSuiteScript := preload("res://tests/suites/sukuna_domain_suite.gd")
const SukunaManagerSmokeSuiteScript := preload("res://tests/suites/sukuna_manager_smoke_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    SukunaSetupRegenSuiteScript.new().register_tests(runner, failures, harness)
    SukunaSnapshotSuiteScript.new().register_tests(runner, failures, harness)
    SukunaKamadoSuiteScript.new().register_tests(runner, failures, harness)
    SukunaDomainSuiteScript.new().register_tests(runner, failures, harness)
    SukunaManagerSmokeSuiteScript.new().register_tests(runner, failures, harness)
