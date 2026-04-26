extends "res://tests/support/gdunit_suite_bridge.gd"

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const DamagePayloadContractTestHelperScript := preload("res://tests/support/damage_payload_contract_test_helper.gd")

var _helper = DamagePayloadContractTestHelperScript.new()


func test_damage_payload_formula_kind_validation() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
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
		fail("missing formula damage_kind validation")
		return

func test_damage_payload_fixed_type_validation() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var errors = _validate_with_sample_mutation(_harness, sample_factory, func(content_index):
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
		fail("missing fixed damage combat_type validation")
		return


func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
	return _helper.validate_with_sample_mutation(harness, sample_factory, mutate)

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
	return _helper.errors_contain(errors, expected_fragment)
