extends RefCounted
class_name SampleBattleFactory

const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
const MatchupCatalogScript := preload("res://src/composition/sample_battle_factory_matchup_catalog.gd")
const ReplayBuilderScript := preload("res://src/composition/sample_battle_factory_replay_builder.gd")
const SetupBuilderScript := preload("res://src/composition/sample_battle_factory_setup_builder.gd")

const BASE_CONTENT_SNAPSHOT_DIRS = [
	"res://content/battle_formats",
	"res://content/combat_types",
	"res://content/units",
	"res://content/skills",
	"res://content/passive_items",
	"res://content/effects",
	"res://content/fields",
	"res://content/passive_skills",
	"res://content/samples",
]

const FORMAL_CHARACTER_IDS := [
	"gojo_satoru",
	"sukuna",
	"kashimo_hajime",
	"obito_juubi_jinchuriki",
]

const FORMAL_CHARACTER_SETUP_MATCHUP_IDS := {
	"gojo_satoru": "gojo_vs_sample",
	"sukuna": "sukuna_setup",
	"kashimo_hajime": "kashimo_vs_sample",
	"obito_juubi_jinchuriki": "obito_vs_sample",
}

var _content_paths_helper = ContentPathsHelperScript.new()
var _matchup_catalog = MatchupCatalogScript.new()
var _replay_builder = ReplayBuilderScript.new()
var _setup_builder = SetupBuilderScript.new()

func build_side_spec(
	unit_definition_ids: PackedStringArray,
	starting_index: int = 0,
	regular_skill_loadout_overrides: Dictionary = {}
) -> Dictionary:
	return _setup_builder.build_side_spec(unit_definition_ids, starting_index, regular_skill_loadout_overrides)

func build_setup_from_side_specs(p1_side_spec: Dictionary, p2_side_spec: Dictionary) -> Variant:
	return _setup_builder.build_setup_from_side_specs(p1_side_spec, p2_side_spec)

func content_snapshot_paths_result() -> Dictionary:
	return _content_paths_helper.build_snapshot_paths(BASE_CONTENT_SNAPSHOT_DIRS)

func content_snapshot_paths_for_setup_result(battle_setup) -> Dictionary:
	return _content_paths_helper.build_snapshot_paths_for_setup(BASE_CONTENT_SNAPSHOT_DIRS, battle_setup)

func content_snapshot_paths() -> PackedStringArray:
	var result := content_snapshot_paths_result()
	if not bool(result.get("ok", false)):
		return PackedStringArray()
	return result.get("data", PackedStringArray())

func content_snapshot_paths_for_setup(battle_setup) -> PackedStringArray:
	var result := content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(result.get("ok", false)):
		return PackedStringArray()
	return result.get("data", PackedStringArray())

func collect_tres_paths_result(dir_path: String) -> Dictionary:
	return _content_paths_helper.collect_tres_paths_result(dir_path)

func collect_tres_paths(dir_path: String) -> Array[String]:
	var result := collect_tres_paths_result(dir_path)
	if not bool(result.get("ok", false)):
		return []
	return result.get("data", [])

func collect_tres_paths_recursive(dir_path: String) -> Array[String]:
	return _content_paths_helper.collect_tres_paths_recursive(dir_path)

func build_setup_by_matchup_id(matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _matchup_catalog.build_setup(_setup_builder, matchup_id, side_regular_skill_overrides)

func build_matchup_setup(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Variant:
	return _setup_builder.build_matchup_setup(
		p1_unit_definition_ids,
		p2_unit_definition_ids,
		side_regular_skill_overrides,
		p1_starting_index,
		p2_starting_index
	)

func formal_character_ids() -> PackedStringArray:
	return PackedStringArray(FORMAL_CHARACTER_IDS)

func build_formal_character_setup(formal_character_definition_id: String, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	var matchup_id := String(FORMAL_CHARACTER_SETUP_MATCHUP_IDS.get(formal_character_definition_id, ""))
	if matchup_id.is_empty():
		return null
	return build_setup_by_matchup_id(matchup_id, side_regular_skill_overrides)

func formal_pair_smoke_cases() -> Array:
	return _matchup_catalog.formal_pair_smoke_cases()

func build_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("sample_default", side_regular_skill_overrides)

func build_gojo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_formal_character_setup("gojo_satoru", side_regular_skill_overrides)

func build_gojo_vs_sukuna_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("gojo_vs_sukuna", side_regular_skill_overrides)

func build_gojo_vs_kashimo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("gojo_vs_kashimo", side_regular_skill_overrides)

func build_gojo_vs_obito_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("gojo_vs_obito", side_regular_skill_overrides)

func build_gojo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("gojo_vs_sample", side_regular_skill_overrides)

func build_sample_vs_gojo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("sample_vs_gojo", side_regular_skill_overrides)

func build_sukuna_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("sukuna_vs_sample", side_regular_skill_overrides)

func build_sukuna_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_formal_character_setup("sukuna", side_regular_skill_overrides)

func build_sukuna_vs_gojo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("sukuna_vs_gojo", side_regular_skill_overrides)

func build_kashimo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_formal_character_setup("kashimo_hajime", side_regular_skill_overrides)

func build_kashimo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("kashimo_vs_sample", side_regular_skill_overrides)

func build_kashimo_vs_gojo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("kashimo_vs_gojo", side_regular_skill_overrides)

func build_obito_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("obito_vs_sample", side_regular_skill_overrides)

func build_obito_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_formal_character_setup("obito_juubi_jinchuriki", side_regular_skill_overrides)

func build_obito_vs_gojo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("obito_vs_gojo", side_regular_skill_overrides)

func build_obito_mirror_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("obito_mirror", side_regular_skill_overrides)

func build_sukuna_vs_kashimo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("sukuna_vs_kashimo", side_regular_skill_overrides)

func build_sukuna_vs_obito_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("sukuna_vs_obito", side_regular_skill_overrides)

func build_kashimo_vs_obito_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("kashimo_vs_obito", side_regular_skill_overrides)

func build_passive_item_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return build_setup_by_matchup_id("passive_item_vs_sample", side_regular_skill_overrides)

func build_demo_replay_input(command_port, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	var battle_setup = build_sample_setup(side_regular_skill_overrides)
	var snapshot_paths_result := content_snapshot_paths_for_setup_result(battle_setup)
	return _replay_builder.build_demo_replay_input(command_port, snapshot_paths_result, battle_setup)

func build_passive_item_demo_replay_input(command_port) -> Variant:
	var battle_setup = build_passive_item_vs_sample_setup()
	var snapshot_paths_result := content_snapshot_paths_for_setup_result(battle_setup)
	return _replay_builder.build_passive_item_demo_replay_input(command_port, snapshot_paths_result, battle_setup)
