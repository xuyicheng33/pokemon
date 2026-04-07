extends RefCounted
class_name SampleBattleFactorySetupAccess

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var baseline_matchup_catalog
var formal_matchup_catalog
var setup_builder

func build_side_spec(
	unit_definition_ids: PackedStringArray,
	starting_index: int = 0,
	regular_skill_loadout_overrides: Dictionary = {}
) -> Dictionary:
	return setup_builder.build_side_spec(unit_definition_ids, starting_index, regular_skill_loadout_overrides)

func build_setup_from_side_specs_result(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Dictionary:
	var battle_setup = setup_builder.build_setup_from_side_specs(p1_side_spec, p2_side_spec)
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build setup from side specs"
		)
	return _ok_result(battle_setup)

func build_setup_by_matchup_id_result(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	if baseline_matchup_catalog.has_matchup(matchup_id):
		return baseline_matchup_catalog.build_setup_result(setup_builder, matchup_id, side_regular_skill_overrides)
	return formal_matchup_catalog.build_setup_result(setup_builder, matchup_id, side_regular_skill_overrides)

func build_matchup_setup_result(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Dictionary:
	var battle_setup = setup_builder.build_matchup_setup(
		p1_unit_definition_ids,
		p2_unit_definition_ids,
		side_regular_skill_overrides,
		p1_starting_index,
		p2_starting_index
	)
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build matchup setup"
		)
	return _ok_result(battle_setup)

func build_sample_setup_result(side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return baseline_matchup_catalog.build_setup_result(
		setup_builder,
		"sample_default",
		side_regular_skill_overrides
	)

func _ok_result(data) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error_code": null,
		"error_message": null,
	}

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"error_code": error_code,
		"error_message": error_message,
	}
