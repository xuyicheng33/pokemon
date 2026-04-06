extends RefCounted
class_name SukunaTestSupport

const FormalCharacterTestSupportScript := preload("res://tests/support/formal_character_test_support.gd")

var _formal_support = FormalCharacterTestSupportScript.new()

func build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
	return _formal_support.build_formal_character_setup(sample_factory, "sukuna", {
		"P1": p1_regular_skill_overrides,
	})

func build_sukuna_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _formal_support.build_matchup_setup(sample_factory, "sukuna_vs_gojo", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_battle_state(core, content_index, battle_setup, seed: int):
	return _formal_support.build_battle_state(core, content_index, battle_setup, seed)

func build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _formal_support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_manual_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _formal_support.build_manual_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _formal_support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func build_manual_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return _formal_support.build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func sum_unit_bst(unit_state) -> int:
	return _formal_support.sum_unit_bst(unit_state)

func resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
	return _formal_support.resolve_matchup_gap_value(owner_total, opponent_total, thresholds, outputs, default_value)

func calc_expected_fixed_effect_damage(core, content_index, effect_id: String, target_unit) -> int:
	var effect_definition = content_index.effects.get(effect_id, null)
	if effect_definition == null or effect_definition.payloads.is_empty():
		return -1
	var payload = effect_definition.payloads[0]
	var type_effectiveness := 1.0
	if not String(payload.combat_type_id).is_empty():
		type_effectiveness = core.service("combat_type_service").calc_effectiveness(String(payload.combat_type_id), target_unit.combat_type_ids)
	return core.service("damage_service").apply_final_mod(max(1, int(payload.amount)), type_effectiveness)
