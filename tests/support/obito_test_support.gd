extends RefCounted
class_name ObitoTestSupport

const FormalCharacterTestSupportScript := preload("res://tests/support/formal_character_test_support.gd")

var _formal_support = FormalCharacterTestSupportScript.new()

func build_obito_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _formal_support.build_formal_character_setup(sample_factory, "obito_juubi_jinchuriki", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_obito_vs_gojo_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _formal_support.build_matchup_setup(sample_factory, "obito_vs_gojo", {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})

func build_obito_mirror_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}, p2_regular_skill_overrides: Dictionary = {}):
	return _formal_support.build_matchup_setup(sample_factory, "obito_mirror", {
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

func find_unit_on_side(battle_state, side_id: String, definition_id: String):
	return _formal_support.find_unit_on_side(battle_state, side_id, definition_id)

func count_effect_instances(unit_state, effect_id: String) -> int:
	return _formal_support.count_effect_instances(unit_state, effect_id)

func find_rule_mod_instance(unit_state, mod_kind: String):
	return _formal_support.find_rule_mod_instance(unit_state, mod_kind)

func count_rule_mod_instances(unit_state, mod_kind: String) -> int:
	return _formal_support.count_rule_mod_instances(unit_state, mod_kind)

func collect_actor_damage_events(event_log: Array, actor_public_id: String) -> Array:
	return _formal_support.collect_actor_damage_events(event_log, actor_public_id)

func collect_target_heal_events(event_log: Array, target_unit_id: String) -> Array:
	return _formal_support.collect_target_heal_events(event_log, target_unit_id)
