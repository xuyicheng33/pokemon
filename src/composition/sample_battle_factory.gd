extends RefCounted
class_name SampleBattleFactory

const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentPathsHelperScript := preload("res://src/composition/sample_battle_factory_content_paths_helper.gd")
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

var _content_paths_helper = ContentPathsHelperScript.new()
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

func content_snapshot_paths() -> PackedStringArray:
	var result := content_snapshot_paths_result()
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
	var dir_access := DirAccess.open(dir_path)
	assert(dir_access != null, "SampleBattleFactory missing snapshot dir: %s" % dir_path)
	var paths: Array[String] = []
	for raw_subdir_name in dir_access.get_directories():
		paths.append_array(collect_tres_paths_recursive("%s/%s" % [dir_path, String(raw_subdir_name)]))
	for raw_file_name in dir_access.get_files():
		var file_name := String(raw_file_name)
		if file_name.get_extension() != "tres":
			continue
		paths.append("%s/%s" % [dir_path, file_name])
	paths.sort()
	return paths

func build_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["sample_pyron", "sample_mossaur", "sample_tidekit"]),
		PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_gojo_vs_sukuna_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_pyron"]),
		PackedStringArray(["sukuna", "sample_tidekit", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_gojo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"]),
		PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_sukuna_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["sukuna", "sample_mossaur", "sample_tidekit"]),
		PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_kashimo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["kashimo_hajime", "sample_mossaur", "sample_pyron"]),
		PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_obito_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["obito_juubi_jinchuriki", "sample_mossaur", "sample_pyron"]),
		PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_sukuna_vs_kashimo_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"]),
		PackedStringArray(["kashimo_hajime", "sample_tidekit", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_sukuna_vs_obito_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"]),
		PackedStringArray(["obito_juubi_jinchuriki", "sample_tidekit", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_kashimo_vs_obito_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["kashimo_hajime", "sample_mossaur", "sample_pyron"]),
		PackedStringArray(["obito_juubi_jinchuriki", "sample_tidekit", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_passive_item_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
	return _build_matchup_setup_from_units(
		PackedStringArray(["sample_pyron_charm", "sample_mossaur", "sample_tidekit"]),
		PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"]),
		side_regular_skill_overrides
	)

func build_demo_replay_input(command_port, side_regular_skill_overrides: Dictionary = {}) -> Variant:
	if command_port == null or not command_port.has_method("build_command"):
		return null
	var snapshot_paths_result := content_snapshot_paths_result()
	if not bool(snapshot_paths_result.get("ok", false)):
		return null
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 17
	replay_input.content_snapshot_paths = snapshot_paths_result.get("data", PackedStringArray())
	replay_input.battle_setup = build_sample_setup(side_regular_skill_overrides)
	replay_input.command_stream = [
		_resolve_command_data(command_port.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_field_call",
		})),
		_resolve_command_data(command_port.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		})),
		_resolve_command_data(command_port.build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		})),
		_resolve_command_data(command_port.build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_whiff",
		})),
	]
	return replay_input

func build_passive_item_demo_replay_input(command_port) -> Variant:
	if command_port == null or not command_port.has_method("build_command"):
		return null
	var snapshot_paths_result := content_snapshot_paths_result()
	if not bool(snapshot_paths_result.get("ok", false)):
		return null
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 1901
	replay_input.content_snapshot_paths = snapshot_paths_result.get("data", PackedStringArray())
	replay_input.battle_setup = build_passive_item_vs_sample_setup()
	replay_input.command_stream = [
		_resolve_command_data(command_port.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		})),
		_resolve_command_data(command_port.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		})),
	]
	return replay_input

func _resolve_command_data(command_result) -> Variant:
	if typeof(command_result) == TYPE_DICTIONARY and command_result.has("ok") and command_result.has("data"):
		return command_result.get("data", null)
	return command_result

func _build_matchup_setup_from_units(
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary
) -> Variant:
	return build_setup_from_side_specs(
		build_side_spec(
			p1_unit_definition_ids,
			0,
			side_regular_skill_overrides.get("P1", {})
		),
		build_side_spec(
			p2_unit_definition_ids,
			0,
			side_regular_skill_overrides.get("P2", {})
		)
	)
