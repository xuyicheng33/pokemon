extends "res://tests/support/formal_character_test_support.gd"
class_name SukunaTestSupport

func build_sukuna_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_formal_character_setup_result(sample_factory, "sukuna", {
		"P1": p1_regular_skill_overrides,
	})

func build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_sukuna_setup_result(sample_factory, p1_regular_skill_overrides))

func build_sukuna_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return build_matchup_setup_result(sample_factory, "sukuna_vs_gojo", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_sukuna_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_sukuna_vs_gojo_setup_result(sample_factory, p1_regular_skill_overrides, p2_regular_skill_overrides))

func calc_expected_fixed_effect_damage(core, content_index, effect_id: String, target_unit) -> int:
	var effect_definition = content_index.effects.get(effect_id, null)
	if effect_definition == null or effect_definition.payloads.is_empty():
		return -1
	var payload = effect_definition.payloads[0]
	var type_effectiveness := 1.0
	if not String(payload.combat_type_id).is_empty():
		type_effectiveness = core.service("combat_type_service").calc_effectiveness(String(payload.combat_type_id), target_unit.combat_type_ids)
	return core.service("damage_service").apply_final_mod(max(1, int(payload.amount)), type_effectiveness)
