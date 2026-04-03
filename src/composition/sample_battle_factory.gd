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

func build_sample_setup(side_regular_skill_overrides: Dictionary = {}):
    var battle_setup = BattleSetupScript.new()
    battle_setup.format_id = "prototype_full_open"
    var p1 = SideSetupScript.new()
    p1.side_id = "P1"
    p1.unit_definition_ids = PackedStringArray(["sample_pyron", "sample_mossaur", "sample_tidekit"])
    p1.starting_index = 0
    p1.regular_skill_loadout_overrides = side_regular_skill_overrides.get("P1", {})
    var p2 = SideSetupScript.new()
    p2.side_id = "P2"
    p2.unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
    p2.starting_index = 0
    p2.regular_skill_loadout_overrides = side_regular_skill_overrides.get("P2", {})
    battle_setup.sides = [p1, p2]
    return battle_setup

func build_gojo_vs_sukuna_setup(side_regular_skill_overrides: Dictionary = {}):
    var battle_setup = build_sample_setup(side_regular_skill_overrides)
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_pyron"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sukuna", "sample_tidekit", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_gojo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}):
    var battle_setup = build_sample_setup(side_regular_skill_overrides)
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_sukuna_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}):
    var battle_setup = build_sample_setup(side_regular_skill_overrides)
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_tidekit"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_kashimo_vs_sample_setup(side_regular_skill_overrides: Dictionary = {}):
    var battle_setup = build_sample_setup(side_regular_skill_overrides)
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["kashimo_hajime", "sample_mossaur", "sample_pyron"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func build_demo_replay_input(command_port, side_regular_skill_overrides: Dictionary = {}):
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

func _resolve_command_data(command_result):
    if typeof(command_result) == TYPE_DICTIONARY and command_result.has("ok") and command_result.has("data"):
        return command_result.get("data", null)
    return command_result
