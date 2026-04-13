extends RefCounted
class_name DamagePayloadContractTestHelper

const CasesScript := preload("res://tests/support/damage_payload_contract_test_helper_cases.gd")

var _cases = CasesScript.new()

func validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
	return _cases.validate_with_sample_mutation(harness, sample_factory, mutate)

func run_formula_skill_inherited_kind_case(core, sample_factory) -> Dictionary:
	return _cases.run_formula_skill_inherited_kind_case(core, sample_factory)

func run_non_skill_formula_damage_kind_case(core, sample_factory) -> Dictionary:
	return _cases.run_non_skill_formula_damage_kind_case(core, sample_factory)

@warning_ignore("shadowed_global_identifier")
func build_initialized_battle(core, content_index, battle_setup, seed: int):
	return _cases.build_initialized_battle(core, content_index, battle_setup, seed)

func find_effect_damage_event(event_log: Array):
	return _cases.find_effect_damage_event(event_log)

func errors_contain(errors: Array, expected_fragment: String) -> bool:
	return _cases.errors_contain(errors, expected_fragment)

func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
	return validate_with_sample_mutation(harness, sample_factory, mutate)

func _run_formula_skill_inherited_kind_case(core, sample_factory) -> Dictionary:
	return run_formula_skill_inherited_kind_case(core, sample_factory)

func _run_non_skill_formula_damage_kind_case(core, sample_factory) -> Dictionary:
	return run_non_skill_formula_damage_kind_case(core, sample_factory)

func _build_sample_setup(sample_factory):
	return _cases._build_sample_setup(sample_factory)

@warning_ignore("shadowed_global_identifier")
func _build_initialized_battle(core, content_index, battle_setup, seed: int):
	return build_initialized_battle(core, content_index, battle_setup, seed)

func _find_effect_damage_event(event_log: Array):
	return find_effect_damage_event(event_log)

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
	return errors_contain(errors, expected_fragment)

func _configure_special_formula_bias(actor, target) -> void:
	_cases._configure_special_formula_bias(actor, target)

func _configure_self_special_formula_bias(actor) -> void:
	_cases._configure_self_special_formula_bias(actor)

func _calc_expected_formula_damage(core, battle_state, actor, target, amount: int, damage_kind: String, type_effectiveness: float) -> int:
	return _cases._calc_expected_formula_damage(core, battle_state, actor, target, amount, damage_kind, type_effectiveness)
