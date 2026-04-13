extends RefCounted
class_name BattleCoreTestHarness

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const PoolHelperScript := preload("res://tests/support/battle_core_test_harness_pool_helper.gd")
const SampleHelperScript := preload("res://tests/support/battle_core_test_harness_sample_helper.gd")

class TestReplacementSelector:
    extends "res://src/battle_core/lifecycle/replacement_selector.gd"

    var next_selection: Variant = null

    func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
        return next_selection

var _pool_helper = PoolHelperScript.new()
var _sample_helper = SampleHelperScript.new()

func pass_result() -> Dictionary:
    return {"ok": true}

func fail_result(message: String) -> Dictionary:
    return {
        "ok": false,
        "error": message,
    }

func build_core() -> Dictionary:
    return _pool_helper.build_core()

func build_manager() -> Dictionary:
    return _pool_helper.build_manager()

func dispose_core_pool() -> void:
    _pool_helper.dispose_core_pool()

func build_sample_factory():
    return _sample_helper.build_sample_factory()

func build_sample_factory_with_overrides(
	registry_path_override: String = "",
	matchup_catalog_path_override: String = "",
	delivery_registry_path_override: String = ""
):
    return _sample_helper.build_sample_factory_with_overrides(
        registry_path_override,
        matchup_catalog_path_override,
        delivery_registry_path_override
    )

func unwrap_sample_factory_result(result: Dictionary, label: String):
    return _sample_helper.unwrap_sample_factory_result(result, label)

func build_setup_by_matchup_id(sample_factory, matchup_id: String, side_regular_skill_overrides: Dictionary = {}):
    return _sample_helper.build_setup_by_matchup_id(sample_factory, matchup_id, side_regular_skill_overrides)

func build_sample_setup(sample_factory, side_regular_skill_overrides: Dictionary = {}):
    return _sample_helper.build_sample_setup(sample_factory, side_regular_skill_overrides)

func build_demo_replay_input(sample_factory, command_port, side_regular_skill_overrides: Dictionary = {}):
    return _sample_helper.build_demo_replay_input(sample_factory, command_port, side_regular_skill_overrides)

func build_passive_item_demo_replay_input(sample_factory, command_port):
    return _sample_helper.build_passive_item_demo_replay_input(sample_factory, command_port)

func build_formal_character_ids(sample_factory) -> PackedStringArray:
    return _sample_helper.build_formal_character_ids(sample_factory)

func build_formal_unit_definition_ids(sample_factory) -> PackedStringArray:
    return _sample_helper.build_formal_unit_definition_ids(sample_factory)

func build_formal_character_setup(sample_factory, character_id: String, side_regular_skill_overrides: Dictionary = {}):
    return _sample_helper.build_formal_character_setup(sample_factory, character_id, side_regular_skill_overrides)

func build_formal_pair_surface_cases(sample_factory) -> Array:
    return _sample_helper.build_formal_pair_surface_cases(sample_factory)

func build_formal_pair_interaction_cases(sample_factory) -> Array:
    return _sample_helper.build_formal_pair_interaction_cases(sample_factory)

func collect_tres_paths_recursive(sample_factory, dir_path: String) -> Array[String]:
    return _sample_helper.collect_tres_paths_recursive(sample_factory, dir_path)

func build_content_snapshot_paths(sample_factory) -> Dictionary:
    return _sample_helper.build_content_snapshot_paths(sample_factory)

func build_content_snapshot_paths_for_setup(sample_factory, battle_setup) -> Dictionary:
    return _sample_helper.build_content_snapshot_paths_for_setup(sample_factory, battle_setup)

func build_loaded_content_index(sample_factory):
    return _sample_helper.build_loaded_content_index(sample_factory)

func build_loaded_content_index_for_setup(sample_factory, battle_setup):
    return _sample_helper.build_loaded_content_index_for_setup(sample_factory, battle_setup)

func build_initialized_battle(core, content_index, sample_factory, battle_seed: int, battle_setup = null):
    core.service("rng_service").reset(battle_seed)
    core.service("id_factory").reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.service("id_factory").next_id("battle")
    battle_state.seed = battle_seed
    battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
    core.service("battle_initializer").initialize_battle(
        battle_state,
        content_index,
        battle_setup if battle_setup != null else build_sample_setup(sample_factory)
    )
    return battle_state

func find_last_event(event_log: Array, event_type: String):
    return _pool_helper.find_last_event(event_log, event_type)

func extract_damage_from_log(event_log: Array, attacker_public_id: String) -> int:
    return _pool_helper.extract_damage_from_log(event_log, attacker_public_id)
