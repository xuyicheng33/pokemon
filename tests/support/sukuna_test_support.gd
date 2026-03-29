extends RefCounted
class_name SukunaTestSupport

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
func _build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
    var battle_setup = sample_factory.build_sample_setup({"P1": p1_regular_skill_overrides})
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func _build_battle_state(core, content_index, battle_setup, seed: int):
    core.rng_service.reset(seed)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, battle_setup)
    return battle_state

func _build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "skill_id": skill_id,
    })

func _build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
    })

func _sum_unit_bst(unit_state) -> int:
    if unit_state == null:
        return 0
    return int(unit_state.max_hp) \
    + int(unit_state.base_attack) \
    + int(unit_state.base_defense) \
    + int(unit_state.base_sp_attack) \
    + int(unit_state.base_sp_defense) \
    + int(unit_state.base_speed) \
    + int(unit_state.max_mp)

func _resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
    var gap: int = abs(owner_total - opponent_total)
    for index in range(thresholds.size()):
        if gap <= int(thresholds[index]):
            return int(outputs[index])
    return default_value
