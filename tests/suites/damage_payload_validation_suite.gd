extends RefCounted
class_name DamagePayloadValidationSuite

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const DamagePayloadContractTestHelperScript := preload("res://tests/support/damage_payload_contract_test_helper.gd")

var _helper = DamagePayloadContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("damage_payload_formula_kind_validation", failures, Callable(self, "_test_formula_damage_kind_validation").bind(harness))
    runner.run_test("damage_payload_fixed_type_validation", failures, Callable(self, "_test_fixed_type_validation").bind(harness))
func _test_formula_damage_kind_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var payload = DamagePayloadScript.new()
        payload.payload_type = "damage"
        payload.amount = 20
        payload.use_formula = true
        payload.damage_kind = "none"
        var effect = EffectDefinitionScript.new()
        effect.id = "test_invalid_formula_damage_kind_effect"
        effect.display_name = "Invalid Formula Damage Kind Effect"
        effect.scope = "target"
        effect.trigger_names = PackedStringArray(["on_cast"])
        effect.duration_mode = "permanent"
        effect.payloads.clear()
        effect.payloads.append(payload)
        content_index.register_resource(effect)
    )
    if not _errors_contain(errors, "effect[test_invalid_formula_damage_kind_effect].damage invalid damage_kind for formula: none"):
        return harness.fail_result("missing formula damage_kind validation")
    return harness.pass_result()


func _test_fixed_type_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var payload = DamagePayloadScript.new()
        payload.payload_type = "damage"
        payload.amount = 10
        payload.use_formula = false
        payload.combat_type_id = "unknown_type"
        var effect = EffectDefinitionScript.new()
        effect.id = "test_fixed_type_validation_effect"
        effect.display_name = "Fixed Type Validation"
        effect.scope = "target"
        effect.trigger_names = PackedStringArray(["on_cast"])
        effect.duration_mode = "permanent"
        effect.payloads.clear()
        effect.payloads.append(payload)
        content_index.register_resource(effect)
    )
    if not _errors_contain(errors, "effect[test_fixed_type_validation_effect].damage combat_type_id missing combat type: unknown_type"):
        return harness.fail_result("missing fixed damage combat_type validation")
    return harness.pass_result()


func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
    return _helper.validate_with_sample_mutation(harness, sample_factory, mutate)

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
    return _helper.errors_contain(errors, expected_fragment)
