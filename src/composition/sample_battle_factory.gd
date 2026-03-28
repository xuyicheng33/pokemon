extends RefCounted
class_name SampleBattleFactory

const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func content_snapshot_paths() -> PackedStringArray:
    return PackedStringArray([
        "res://content/samples/sample_battle_format.tres",
        "res://content/combat_types/fire.tres",
        "res://content/combat_types/water.tres",
        "res://content/combat_types/wind.tres",
        "res://content/combat_types/thunder.tres",
        "res://content/combat_types/ice.tres",
        "res://content/combat_types/earth.tres",
        "res://content/combat_types/wood.tres",
        "res://content/combat_types/steel.tres",
        "res://content/combat_types/light.tres",
        "res://content/combat_types/dark.tres",
        "res://content/combat_types/space.tres",
        "res://content/combat_types/demon.tres",
        "res://content/combat_types/psychic.tres",
        "res://content/combat_types/spirit.tres",
        "res://content/combat_types/fighting.tres",
        "res://content/combat_types/holy.tres",
        "res://content/combat_types/dragon.tres",
        "res://content/units/sample_pyron.tres",
        "res://content/units/sample_mossaur.tres",
        "res://content/units/sample_tidekit.tres",
        "res://content/units/sukuna.tres",
        "res://content/skills/sample_strike.tres",
        "res://content/skills/sample_quick_jab.tres",
        "res://content/skills/sample_field_call.tres",
        "res://content/skills/sample_pyro_blast.tres",
        "res://content/skills/sample_tide_surge.tres",
        "res://content/skills/sample_vine_slash.tres",
        "res://content/skills/sample_whiff.tres",
        "res://content/skills/sample_ultimate_burst.tres",
        "res://content/skills/sukuna_kai.tres",
        "res://content/skills/sukuna_hatsu.tres",
        "res://content/skills/sukuna_hiraku.tres",
        "res://content/skills/sukuna_reverse_ritual.tres",
        "res://content/skills/sukuna_fukuma_mizushi.tres",
        "res://content/effects/sample_apply_focus_field.tres",
        "res://content/effects/sukuna_apply_kamado.tres",
        "res://content/effects/sukuna_kamado_mark.tres",
        "res://content/effects/sukuna_kamado_explode.tres",
        "res://content/effects/sukuna_reverse_heal.tres",
        "res://content/effects/sukuna_apply_domain_field.tres",
        "res://content/effects/sukuna_domain_cast_buff.tres",
        "res://content/effects/sukuna_domain_rollback.tres",
        "res://content/effects/sukuna_domain_expire_burst.tres",
        "res://content/effects/sukuna_domain_expire_seal.tres",
        "res://content/effects/sukuna_refresh_love_regen.tres",
        "res://content/fields/sample_focus_field.tres",
        "res://content/fields/sukuna_malevolent_shrine.tres",
        "res://content/passive_skills/sukuna_teach_love.tres",
    ])

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

func build_demo_replay_input(command_port, side_regular_skill_overrides: Dictionary = {}):
    assert(command_port != null and command_port.has_method("build_command"), "build_demo_replay_input requires build_command port")
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 17
    replay_input.content_snapshot_paths = content_snapshot_paths()
    replay_input.battle_setup = build_sample_setup(side_regular_skill_overrides)
    replay_input.command_stream = [
        command_port.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_field_call",
        }),
        command_port.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
        command_port.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        command_port.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    return replay_input
