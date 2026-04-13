extends GdUnitTestSuite

# 入口 wrapper；断言本体下沉到 extension_targeting_accuracy/ 子目录。
const RequiredTargetEffectsSuiteScript := preload("res://test/suites/extension_targeting_accuracy/required_target_effects_suite.gd")
const RequiredTargetSameOwnerSuiteScript := preload("res://test/suites/extension_targeting_accuracy/required_target_same_owner_suite.gd")
const EffectRefreshSuiteScript := preload("res://test/suites/extension_targeting_accuracy/effect_refresh_suite.gd")
const IncomingAccuracySuiteScript := preload("res://test/suites/extension_targeting_accuracy/incoming_accuracy_suite.gd")

