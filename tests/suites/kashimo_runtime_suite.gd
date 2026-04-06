extends RefCounted
class_name KashimoRuntimeSuite

# Entry wrapper; concrete assertions live under tests/suites/kashimo_runtime/.
const ChargeLoopSuiteScript := preload("res://tests/suites/kashimo_runtime/charge_loop_suite.gd")
const KyokyoSuiteScript := preload("res://tests/suites/kashimo_runtime/kyokyo_suite.gd")
const PassiveCounterSuiteScript := preload("res://tests/suites/kashimo_runtime/passive_counter_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	ChargeLoopSuiteScript.new().register_tests(runner, failures, harness)
	KyokyoSuiteScript.new().register_tests(runner, failures, harness)
	PassiveCounterSuiteScript.new().register_tests(runner, failures, harness)
