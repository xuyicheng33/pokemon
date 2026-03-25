extends RefCounted
class_name SampleBattleFactory

const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func content_snapshot_paths() -> PackedStringArray:
    return PackedStringArray([
        "res://content/samples/sample_battle_format.tres",
        "res://content/units/sample_pyron.tres",
        "res://content/units/sample_mossaur.tres",
        "res://content/units/sample_tidekit.tres",
        "res://content/skills/sample_strike.tres",
        "res://content/skills/sample_quick_jab.tres",
        "res://content/skills/sample_field_call.tres",
        "res://content/skills/sample_whiff.tres",
        "res://content/skills/sample_ultimate_burst.tres",
        "res://content/effects/sample_apply_focus_field.tres",
        "res://content/fields/sample_focus_field.tres",
    ])

func build_sample_setup():
    var battle_setup = BattleSetupScript.new()
    battle_setup.format_id = "prototype_full_open"
    var p1 = SideSetupScript.new()
    p1.side_id = "P1"
    p1.unit_definition_ids = PackedStringArray(["sample_pyron", "sample_mossaur", "sample_tidekit"])
    p1.starting_index = 0
    var p2 = SideSetupScript.new()
    p2.side_id = "P2"
    p2.unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
    p2.starting_index = 0
    battle_setup.sides = [p1, p2]
    return battle_setup

func build_demo_replay_input(command_builder):
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 17
    replay_input.content_snapshot_paths = content_snapshot_paths()
    replay_input.battle_setup = build_sample_setup()
    replay_input.command_stream = [
        command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_field_call",
        }),
        command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
        command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    return replay_input
