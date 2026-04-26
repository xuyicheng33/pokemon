extends RefCounted
class_name SampleBattleFactorySetupAccess

const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var baseline_matchup_catalog: SampleBattleFactoryBaselineMatchupCatalog = null
var formal_matchup_catalog: SampleBattleFactoryFormalMatchupCatalog = null

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

func build_setup_from_side_specs_result(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Dictionary:
	var battle_setup = build_setup_from_side_specs(p1_side_spec, p2_side_spec)
	if battle_setup == null:
		return _error_result(
			ErrorCodesScript.INVALID_COMPOSITION,
			"SampleBattleFactory failed to build setup from side specs"
		)
	return ResultEnvelopeHelperScript.ok(battle_setup)

func build_setup_by_matchup_id_result(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var baseline_owner_result := _matchup_owner_result(baseline_matchup_catalog.load_matchups_result(), matchup_id, "baseline")
	if not bool(baseline_owner_result.get("ok", false)):
		return baseline_owner_result
	if bool(baseline_owner_result.get("data", {}).get("found", false)):
		return baseline_matchup_catalog.build_setup_result(self, matchup_id, side_regular_skill_overrides)
	var formal_owner_result := _matchup_owner_result(formal_matchup_catalog.load_matchups_result(), matchup_id, "formal")
	if not bool(formal_owner_result.get("ok", false)):
		return formal_owner_result
	if not bool(formal_owner_result.get("data", {}).get("found", false)):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory unknown matchup_id: %s" % matchup_id
		)
	return formal_matchup_catalog.build_setup_result(self, matchup_id, side_regular_skill_overrides)

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

func build_matchup_setup_result(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Dictionary:
	var battle_setup = build_matchup_setup(
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
	return ResultEnvelopeHelperScript.ok(battle_setup)

func build_sample_setup_result(side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return baseline_matchup_catalog.build_setup_result(
		self,
		"sample_default",
		side_regular_skill_overrides
	)

func _build_side_setup_from_spec(side_id: String, side_spec: Dictionary) -> Variant:
	var side_setup = SideSetupScript.new()
	side_setup.side_id = side_id
	side_setup.unit_definition_ids = PackedStringArray(side_spec.get("unit_definition_ids", PackedStringArray()))
	side_setup.starting_index = int(side_spec.get("starting_index", 0))
	side_setup.regular_skill_loadout_overrides = side_spec.get("regular_skill_loadout_overrides", {}).duplicate(true)
	return side_setup

func _error_result(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)

func _matchup_owner_result(catalog_result: Dictionary, matchup_id: String, source_label: String) -> Dictionary:
	if not bool(catalog_result.get("ok", false)):
		return _error_result(
			str(catalog_result.get("error_code", ErrorCodesScript.INVALID_BATTLE_SETUP)),
			"SampleBattleFactory failed to load %s matchup catalog while resolving %s: %s" % [
				source_label,
				matchup_id,
				String(catalog_result.get("error_message", "unknown error")),
			]
		)
	var matchups = catalog_result.get("data", {}).get("matchups", {})
	if not (matchups is Dictionary):
		return _error_result(
			ErrorCodesScript.INVALID_BATTLE_SETUP,
			"SampleBattleFactory %s matchup catalog missing matchups dictionary while resolving %s" % [
				source_label,
				matchup_id,
			]
		)
	return ResultEnvelopeHelperScript.ok({"found": matchups.has(matchup_id)})
