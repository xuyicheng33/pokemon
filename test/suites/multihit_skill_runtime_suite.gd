extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 multihit_skill_runtime/ 子目录。
const MultihitSkillDamageSuiteScript := preload("res://test/suites/multihit_skill_runtime/damage_segments_suite.gd")
const MultihitSkillTriggerSuiteScript := preload("res://test/suites/multihit_skill_runtime/segment_triggers_suite.gd")
const MultihitSkillExecuteSuiteScript := preload("res://test/suites/multihit_skill_runtime/execute_short_circuit_suite.gd")
const MultihitSkillValidationSuiteScript := preload("res://test/suites/multihit_skill_runtime/validation_suite.gd")

