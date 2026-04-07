extends RefCounted
class_name CombatTypeTestHelper

const CasesScript := preload("res://tests/support/combat_type_test_helper_cases.gd")

var _cases = CasesScript.new()

func validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
	return _cases.validate_with_sample_mutation(harness, sample_factory, mutate)

func run_direct_damage_case(harness, core, sample_factory, skill_type_id: String, final_mod: Variant) -> Dictionary:
	return _cases.run_direct_damage_case(harness, core, sample_factory, skill_type_id, final_mod)

func run_formula_skill_case(harness, core, sample_factory) -> Dictionary:
	return _cases.run_formula_skill_case(harness, core, sample_factory)

func run_non_skill_formula_case(harness, core, sample_factory) -> Dictionary:
	return _cases.run_non_skill_formula_case(harness, core, sample_factory)

func build_initialized_battle(core, content_index, battle_setup, seed: int):
	return _cases.build_initialized_battle(core, content_index, battle_setup, seed)

func find_actor_damage_event(event_log: Array, actor_public_id: String):
	return _cases.find_actor_damage_event(event_log, actor_public_id)

func find_effect_damage_event(event_log: Array):
	return _cases.find_effect_damage_event(event_log)

func errors_contain(errors: Array, expected_fragment: String) -> bool:
	return _cases.errors_contain(errors, expected_fragment)

func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
	return validate_with_sample_mutation(harness, sample_factory, mutate)

func _run_direct_damage_case(harness, core, sample_factory, skill_type_id: String, final_mod: Variant) -> Dictionary:
	return run_direct_damage_case(harness, core, sample_factory, skill_type_id, final_mod)

func _run_formula_skill_case(harness, core, sample_factory) -> Dictionary:
	return run_formula_skill_case(harness, core, sample_factory)

func _run_non_skill_formula_case(harness, core, sample_factory) -> Dictionary:
	return run_non_skill_formula_case(harness, core, sample_factory)

func _build_initialized_battle(core, content_index, battle_setup, seed: int):
	return build_initialized_battle(core, content_index, battle_setup, seed)

func _find_actor_damage_event(event_log: Array, actor_public_id: String):
	return find_actor_damage_event(event_log, actor_public_id)

func _find_effect_damage_event(event_log: Array):
	return find_effect_damage_event(event_log)

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
	return errors_contain(errors, expected_fragment)
