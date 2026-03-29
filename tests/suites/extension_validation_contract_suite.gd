extends RefCounted
class_name ExtensionValidationContractSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("extension_validation_contract", failures, Callable(self, "_test_extension_validation_contract").bind(harness))
func _test_extension_validation_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var marker_effect = EffectDefinitionScript.new()
    marker_effect.id = "test_required_marker"
    marker_effect.display_name = "Required Marker"
    marker_effect.scope = "self"
    content_index.register_resource(marker_effect)

    var bad_action_payload = RuleModPayloadScript.new()
    bad_action_payload.payload_type = "rule_mod"
    bad_action_payload.mod_kind = "action_legality"
    bad_action_payload.mod_op = "deny"
    bad_action_payload.value = "missing_skill_id"
    bad_action_payload.scope = "self"
    bad_action_payload.duration_mode = "turns"
    bad_action_payload.duration = 1
    bad_action_payload.decrement_on = "turn_start"
    bad_action_payload.stacking = "replace"
    var bad_action_effect = EffectDefinitionScript.new()
    bad_action_effect.id = "test_bad_action_legality"
    bad_action_effect.display_name = "Bad Action Legality"
    bad_action_effect.scope = "self"
    bad_action_effect.payloads.append(bad_action_payload)
    content_index.register_resource(bad_action_effect)

    var bad_accuracy_payload = RuleModPayloadScript.new()
    bad_accuracy_payload.payload_type = "rule_mod"
    bad_accuracy_payload.mod_kind = "incoming_accuracy"
    bad_accuracy_payload.mod_op = "add"
    bad_accuracy_payload.value = 1.5
    bad_accuracy_payload.scope = "self"
    bad_accuracy_payload.duration_mode = "permanent"
    bad_accuracy_payload.decrement_on = "turn_end"
    bad_accuracy_payload.stacking = "none"
    var bad_accuracy_effect = EffectDefinitionScript.new()
    bad_accuracy_effect.id = "test_bad_incoming_accuracy"
    bad_accuracy_effect.display_name = "Bad Incoming Accuracy"
    bad_accuracy_effect.scope = "self"
    bad_accuracy_effect.payloads.append(bad_accuracy_payload)
    content_index.register_resource(bad_accuracy_effect)

    var bad_required_scope = EffectDefinitionScript.new()
    bad_required_scope.id = "test_bad_required_scope"
    bad_required_scope.display_name = "Bad Required Scope"
    bad_required_scope.scope = "self"
    bad_required_scope.required_target_effects = PackedStringArray([marker_effect.id])
    content_index.register_resource(bad_required_scope)

    var bad_required_missing = EffectDefinitionScript.new()
    bad_required_missing.id = "test_bad_required_missing"
    bad_required_missing.display_name = "Bad Required Missing"
    bad_required_missing.scope = "target"
    bad_required_missing.required_target_effects = PackedStringArray(["missing_required_effect"])
    content_index.register_resource(bad_required_missing)

    var bad_required_duplicate = EffectDefinitionScript.new()
    bad_required_duplicate.id = "test_bad_required_duplicate"
    bad_required_duplicate.display_name = "Bad Required Duplicate"
    bad_required_duplicate.scope = "target"
    bad_required_duplicate.required_target_effects = PackedStringArray([marker_effect.id, marker_effect.id])
    content_index.register_resource(bad_required_duplicate)

    var errors: Array = content_index.validate_snapshot()
    var needles := [
        "effect[test_bad_action_legality].rule_mod invalid: action_legality value missing skill: missing_skill_id",
        "effect[test_bad_incoming_accuracy].rule_mod invalid: incoming_accuracy value must be int",
        "effect[test_bad_required_scope].required_target_effects requires scope=target",
        "effect[test_bad_required_missing].required_target_effects missing effect: missing_required_effect",
        "effect[test_bad_required_duplicate].required_target_effects duplicated effect: test_required_marker",
    ]
    for needle in needles:
        if not _has_error(errors, needle):
            return harness.fail_result("extension validation missing error: %s" % needle)
    return harness.pass_result()


func _has_error(errors: Array, needle: String) -> bool:
    for error_msg in errors:
        if String(error_msg).find(needle) != -1:
            return true
    return false

func _has_event(event_log: Array, predicate: Callable) -> bool:
    for log_event in event_log:
        if predicate.call(log_event):
            return true
    return false
