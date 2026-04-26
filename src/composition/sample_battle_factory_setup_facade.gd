extends RefCounted
class_name SampleBattleFactorySetupFacade

var setup_access: SampleBattleFactorySetupAccess = null
var formal_access: SampleBattleFactoryFormalAccess = null

func build_side_spec(
	unit_definition_ids: PackedStringArray,
	starting_index: int = 0,
	regular_skill_loadout_overrides: Dictionary = {}
) -> Dictionary:
	return setup_access.build_side_spec(unit_definition_ids, starting_index, regular_skill_loadout_overrides)

func build_setup_from_side_specs_result(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Dictionary:
	return setup_access.build_setup_from_side_specs_result(p1_side_spec, p2_side_spec)

func build_setup_by_matchup_id_result(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return setup_access.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides)

func build_matchup_setup_result(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Dictionary:
	return setup_access.build_matchup_setup_result(
		p1_unit_definition_ids,
		p2_unit_definition_ids,
		side_regular_skill_overrides,
		p1_starting_index,
		p2_starting_index
	)

func build_sample_setup_result(side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return setup_access.build_sample_setup_result(side_regular_skill_overrides)

func build_formal_character_setup_result(character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return formal_access.build_formal_character_setup_result(character_id, side_regular_skill_overrides)
