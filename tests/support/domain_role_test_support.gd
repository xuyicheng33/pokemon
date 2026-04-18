extends RefCounted
class_name DomainRoleTestSupport

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const UnitBstHelperScript := preload("res://src/shared/unit_bst_helper.gd")

@warning_ignore("shadowed_global_identifier")
func build_battle_state(core, content_index, battle_setup, seed: int):
    core.service("rng_service").reset(seed)
    core.service("id_factory").reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.service("id_factory").next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
    if core.service("battle_initializer").initialize_battle(battle_state, content_index, battle_setup):
        battle_state.rebuild_indexes()
    return battle_state

func build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return core.service("command_builder").build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "skill_id": skill_id,
    })

func build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return core.service("command_builder").build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
    })

func build_manual_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
    return core.service("command_builder").build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.SWITCH,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "target_public_id": target_public_id,
    })

func build_manual_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return core.service("command_builder").build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.ULTIMATE,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "skill_id": skill_id,
    })

func sum_unit_bst(unit_state) -> int:
    return UnitBstHelperScript.sum_unit_bst(unit_state)

func resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
    var gap: int = abs(owner_total - opponent_total)
    for index in range(thresholds.size()):
        if gap <= int(thresholds[index]):
            return int(outputs[index])
    return default_value
