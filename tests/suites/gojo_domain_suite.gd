extends RefCounted
class_name GojoDomainSuite

const GojoMugenSuiteScript := preload("res://tests/suites/gojo_mugen_suite.gd")
const GojoUnlimitedVoidSuiteScript := preload("res://tests/suites/gojo_unlimited_void_suite.gd")
const GojoMiscRuntimeSuiteScript := preload("res://tests/suites/gojo_misc_runtime_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	GojoMugenSuiteScript.new().register_tests(runner, failures, harness)
	GojoUnlimitedVoidSuiteScript.new().register_tests(runner, failures, harness)
	GojoMiscRuntimeSuiteScript.new().register_tests(runner, failures, harness)
