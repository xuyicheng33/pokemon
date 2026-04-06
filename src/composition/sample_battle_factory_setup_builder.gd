extends RefCounted
class_name SampleBattleFactorySetupBuilder

const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")

func build_side_spec(
	unit_definition_ids: PackedStringArray,
	starting_index: int = 0,
	regular_skill_loadout_overrides: Dictionary = {}
) -> Dictionary:
	return {
		"unit_definition_ids": unit_definition_ids,
		"starting_index": starting_index,
		"regular_skill_loadout_overrides": regular_skill_loadout_overrides.duplicate(true),
	}

func build_setup_from_side_specs(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Variant:
	var battle_setup = BattleSetupScript.new()
	battle_setup.format_id = "prototype_full_open"
	battle_setup.sides = [
		_build_side_setup_from_spec("P1", p1_side_spec),
		_build_side_setup_from_spec("P2", p2_side_spec),
	]
	return battle_setup

func build_matchup_setup(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Variant:
	return build_setup_from_side_specs(
		build_side_spec(
			p1_unit_definition_ids,
			p1_starting_index,
			side_regular_skill_overrides.get("P1", {})
		),
		build_side_spec(
			p2_unit_definition_ids,
			p2_starting_index,
			side_regular_skill_overrides.get("P2", {})
		)
	)

func _build_side_setup_from_spec(side_id: String, side_spec: Dictionary) -> Variant:
	var side_setup = SideSetupScript.new()
	side_setup.side_id = side_id
	side_setup.unit_definition_ids = PackedStringArray(side_spec.get("unit_definition_ids", PackedStringArray()))
	side_setup.starting_index = int(side_spec.get("starting_index", 0))
	side_setup.regular_skill_loadout_overrides = side_spec.get("regular_skill_loadout_overrides", {}).duplicate(true)
	return side_setup
