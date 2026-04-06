extends RefCounted
class_name ExtensionTargetingAccuracySuite

# 入口 wrapper；断言本体下沉到 extension_targeting_accuracy/ 子目录。
const RequiredTargetEffectsSuiteScript := preload("res://tests/suites/extension_targeting_accuracy/required_target_effects_suite.gd")
const RequiredTargetSameOwnerSuiteScript := preload("res://tests/suites/extension_targeting_accuracy/required_target_same_owner_suite.gd")
const EffectRefreshSuiteScript := preload("res://tests/suites/extension_targeting_accuracy/effect_refresh_suite.gd")
const IncomingAccuracySuiteScript := preload("res://tests/suites/extension_targeting_accuracy/incoming_accuracy_suite.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    RequiredTargetEffectsSuiteScript.new().register_tests(runner, failures, harness)
    RequiredTargetSameOwnerSuiteScript.new().register_tests(runner, failures, harness)
    EffectRefreshSuiteScript.new().register_tests(runner, failures, harness)
    IncomingAccuracySuiteScript.new().register_tests(runner, failures, harness)
