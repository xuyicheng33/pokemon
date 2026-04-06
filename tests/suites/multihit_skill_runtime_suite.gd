extends RefCounted
class_name MultihitSkillRuntimeSuite

# 入口 wrapper；断言本体下沉到 multihit_skill_runtime/ 子目录。
const MultihitSkillDamageSuiteScript := preload("res://tests/suites/multihit_skill_runtime/damage_segments_suite.gd")
const MultihitSkillTriggerSuiteScript := preload("res://tests/suites/multihit_skill_runtime/segment_triggers_suite.gd")
const MultihitSkillExecuteSuiteScript := preload("res://tests/suites/multihit_skill_runtime/execute_short_circuit_suite.gd")
const MultihitSkillValidationSuiteScript := preload("res://tests/suites/multihit_skill_runtime/validation_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    MultihitSkillDamageSuiteScript.new().register_tests(runner, failures, harness)
    MultihitSkillTriggerSuiteScript.new().register_tests(runner, failures, harness)
    MultihitSkillExecuteSuiteScript.new().register_tests(runner, failures, harness)
    MultihitSkillValidationSuiteScript.new().register_tests(runner, failures, harness)
