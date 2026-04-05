extends RefCounted
class_name SampleBattleFactory

const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func content_snapshot_paths() -> PackedStringArray:
    var collect_dirs := PackedStringArray([
        "res://content/battle_formats",
        "res://content/combat_types",
        "res://content/units",
        "res://content/skills",
        "res://content/passive_items",
        "res://content/effects",
        "res://content/fields",
        "res://content/passive_skills",
        "res://content/samples",
    ])
    var paths: Array[String] = []
    var seen: Dictionary = {}
    for raw_dir_path in collect_dirs:
        var dir_path := String(raw_dir_path)
        for file_path in collect_tres_paths_recursive(dir_path):
            if seen.has(file_path):
                continue
            seen[file_path] = true
            paths.append(file_path)
    paths.sort()
    return PackedStringArray(paths)

func collect_tres_paths_recursive(dir_path: String) -> Array[String]:
    var dir_access := DirAccess.open(dir_path)
    if dir_access == null:
        return []
    var paths: Array[String] = []
    for raw_subdir_name in dir_access.get_directories():
        var subdir_name := String(raw_subdir_name)
        paths.append_array(collect_tres_paths_recursive("%s/%s" % [dir_path, subdir_name]))
    for raw_file_name in dir_access.get_files():
        var file_name := String(raw_file_name)
        if file_name.get_extension() != "tres":
            continue
        paths.append("%s/%s" % [dir_path, file_name])
    paths.sort()
    return paths

func build_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
    return _build_custom_setup(
        PackedStringArray(["sample_pyron", "sample_mossaur", "sample_tidekit"]),
        PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"]),
        side_regular_skill_overrides
    )

func build_gojo_vs_sukuna_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
    return _build_custom_setup(
        PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_pyron"]),
        PackedStringArray(["sukuna", "sample_tidekit", "sample_mossaur"]),
        side_regular_skill_overrides
    )

func build_gojo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
    return _build_custom_setup(
        PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"]),
        PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]),
        side_regular_skill_overrides
    )

func build_sukuna_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
    return _build_custom_setup(
        PackedStringArray(["sukuna", "sample_mossaur", "sample_tidekit"]),
        PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]),
        side_regular_skill_overrides
    )

func build_kashimo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
    return _build_custom_setup(
        PackedStringArray(["kashimo_hajime", "sample_mossaur", "sample_pyron"]),
        PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"]),
        side_regular_skill_overrides
    )

func build_obito_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
    return _build_custom_setup(
        PackedStringArray(["obito_juubi_jinchuriki", "sample_mossaur", "sample_pyron"]),
        PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]),
        side_regular_skill_overrides
    )

func build_passive_item_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}) -> Variant:
    return _build_custom_setup(
        PackedStringArray(["sample_pyron_charm", "sample_mossaur", "sample_tidekit"]),
        PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"]),
        side_regular_skill_overrides
    )

func build_demo_replay_input(command_port, side_regular_skill_overrides: Dictionary = {}) -> Variant:
    if command_port == null or not command_port.has_method("build_command"):
        return null
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 17
    replay_input.content_snapshot_paths = content_snapshot_paths()
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
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 1901
    replay_input.content_snapshot_paths = content_snapshot_paths()
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

func _build_custom_setup(
    p1_unit_definition_ids: PackedStringArray,
    p2_unit_definition_ids: PackedStringArray,
    side_regular_skill_overrides: Dictionary = {},
    p1_starting_index: int = 0,
    p2_starting_index: int = 0
) -> Variant:
    var battle_setup = BattleSetupScript.new()
    battle_setup.format_id = "prototype_full_open"
    battle_setup.sides = [
        _build_side_setup("P1", p1_unit_definition_ids, p1_starting_index, side_regular_skill_overrides),
        _build_side_setup("P2", p2_unit_definition_ids, p2_starting_index, side_regular_skill_overrides),
    ]
    return battle_setup

func _build_side_setup(side_id: String, unit_definition_ids: PackedStringArray, starting_index: int, side_regular_skill_overrides: Dictionary) -> Variant:
    var side_setup = SideSetupScript.new()
    side_setup.side_id = side_id
    side_setup.unit_definition_ids = unit_definition_ids
    side_setup.starting_index = starting_index
    side_setup.regular_skill_loadout_overrides = side_regular_skill_overrides.get(side_id, {})
    return side_setup
