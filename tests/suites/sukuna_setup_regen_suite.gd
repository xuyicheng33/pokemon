extends RefCounted
class_name SukunaSetupRegenSuite

const SukunaSetupLoadoutRegenSuiteScript := preload("res://tests/suites/sukuna_setup_loadout_regen_suite.gd")
const SukunaTeachLoveBandSuiteScript := preload("res://tests/suites/sukuna_teach_love_band_suite.gd")
const SukunaSetupSkillRuntimeSuiteScript := preload("res://tests/suites/sukuna_setup_skill_runtime_suite.gd")
const SukunaSetupUltimateWindowSuiteScript := preload("res://tests/suites/sukuna_setup_ultimate_window_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	SukunaSetupLoadoutRegenSuiteScript.new().register_tests(runner, failures, harness)
	SukunaTeachLoveBandSuiteScript.new().register_tests(runner, failures, harness)
	SukunaSetupSkillRuntimeSuiteScript.new().register_tests(runner, failures, harness)
	SukunaSetupUltimateWindowSuiteScript.new().register_tests(runner, failures, harness)
