extends RefCounted
class_name BattleCoreTestHarness

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class TestReplacementSelector:
    extends "res://src/battle_core/lifecycle/replacement_selector.gd"

    var next_selection: Variant = null

    func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
        return next_selection

var _core_pool: Array = []
var _manager_pool: Array = []

func pass_result() -> Dictionary:
    return {"ok": true}

func fail_result(message: String) -> Dictionary:
    return {
        "ok": false,
        "error": message,
    }

func build_core() -> Dictionary:
    var composer = BattleCoreComposerScript.new()
    if composer == null:
        return {"error": "BattleCoreComposer init failed"}
    var core = composer.compose()
    if core == null:
        return {"error": "compose returned null"}
    var required_services: Array[String] = [
        "command_builder",
        "replay_runner",
        "battle_initializer",
        "turn_loop_controller",
        "battle_logger",
        "id_factory",
        "rng_service",
        "public_snapshot_builder",
    ]
    for service_name in required_services:
        if core.service(service_name) == null:
            return {"error": "missing core service: %s" % service_name}
    _core_pool.append(core)
    return {"core": core}

func build_manager() -> Dictionary:
    var composer = BattleCoreComposerScript.new()
    if composer == null:
        return {"error": "BattleCoreComposer init failed"}
    var manager = composer.compose_manager()
    if manager == null:
        return {"error": "compose_manager returned null"}
    var missing_dependency := String(manager.resolve_missing_dependency())
    if not missing_dependency.is_empty():
        return {"error": "missing manager port: %s" % missing_dependency}
    _manager_pool.append(manager)
    return {"manager": manager, "composer": composer}

func dispose_core_pool() -> void:
    for core in _core_pool:
        if core != null and core.has_method("dispose"):
            core.dispose()
    _core_pool.clear()
    for manager in _manager_pool:
        if manager != null and manager.has_method("dispose"):
            manager.dispose()
    _manager_pool.clear()

func build_sample_factory():
    var sample_factory = SampleBattleFactoryScript.new()
    if sample_factory == null:
        return null
    return sample_factory

func build_sample_factory_with_overrides(
	registry_path_override: String = "",
	matchup_catalog_path_override: String = "",
	delivery_registry_path_override: String = ""
):
    var sample_factory = build_sample_factory()
    if sample_factory == null:
        return null
    if not String(registry_path_override).strip_edges().is_empty():
        sample_factory.configure_registry_path_override(registry_path_override)
    if not String(matchup_catalog_path_override).strip_edges().is_empty():
        sample_factory.configure_matchup_catalog_path_override(matchup_catalog_path_override)
    if not String(delivery_registry_path_override).strip_edges().is_empty():
        sample_factory.configure_delivery_registry_path_override(delivery_registry_path_override)
    return sample_factory

func unwrap_sample_factory_result(result: Dictionary, label: String):
    assert(bool(result.get("ok", false)), "SampleBattleFactory %s failed: %s" % [label, str(result.get("error_message", "unknown error"))])
    return result.get("data", null)

func build_setup_by_matchup_id(sample_factory, matchup_id: String, side_regular_skill_overrides: Dictionary = {}):
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return null
    return unwrap_sample_factory_result(
        sample_factory.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides),
        "build_setup_by_matchup_id(%s)" % matchup_id
    )

func build_sample_setup(sample_factory, side_regular_skill_overrides: Dictionary = {}):
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return null
    return unwrap_sample_factory_result(
        sample_factory.build_sample_setup_result(side_regular_skill_overrides),
        "build_sample_setup"
    )

func build_demo_replay_input(sample_factory, command_port, side_regular_skill_overrides: Dictionary = {}):
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return null
    return unwrap_sample_factory_result(
        sample_factory.build_demo_replay_input_result(command_port, side_regular_skill_overrides),
        "build_demo_replay_input"
    )

func build_passive_item_demo_replay_input(sample_factory, command_port):
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return null
    return unwrap_sample_factory_result(
        sample_factory.build_passive_item_demo_replay_input_result(command_port),
        "build_passive_item_demo_replay_input"
    )

func build_formal_character_ids(sample_factory) -> PackedStringArray:
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return PackedStringArray()
    return unwrap_sample_factory_result(sample_factory.formal_character_ids_result(), "formal_character_ids")

func build_formal_unit_definition_ids(sample_factory) -> PackedStringArray:
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return PackedStringArray()
    return unwrap_sample_factory_result(sample_factory.formal_unit_definition_ids_result(), "formal_unit_definition_ids")

func build_formal_character_setup(sample_factory, character_id: String, side_regular_skill_overrides: Dictionary = {}):
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return null
    return unwrap_sample_factory_result(
        sample_factory.build_formal_character_setup_result(character_id, side_regular_skill_overrides),
        "build_formal_character_setup(%s)" % character_id
    )

func build_formal_pair_surface_cases(sample_factory) -> Array:
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return []
    return unwrap_sample_factory_result(sample_factory.formal_pair_surface_cases_result(), "formal_pair_surface_cases")

func build_formal_pair_interaction_cases(sample_factory) -> Array:
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return []
    return unwrap_sample_factory_result(sample_factory.formal_pair_interaction_cases_result(), "formal_pair_interaction_cases")

func collect_tres_paths_recursive(sample_factory, dir_path: String) -> Array[String]:
    if sample_factory == null:
        assert(false, "SampleBattleFactory init failed")
        return []
    return unwrap_sample_factory_result(
        sample_factory.collect_tres_paths_recursive_result(dir_path),
        "collect_tres_paths_recursive(%s)" % dir_path
    )

func build_content_snapshot_paths(sample_factory) -> Dictionary:
    if sample_factory == null:
        return {"error": "SampleBattleFactory init failed"}
    var snapshot_result: Dictionary = sample_factory.content_snapshot_paths_result()
    if not bool(snapshot_result.get("ok", false)):
        return {"error": str(snapshot_result.get("error_message", "content snapshot path build failed"))}
    return {"paths": snapshot_result.get("data", PackedStringArray())}

func build_content_snapshot_paths_for_setup(sample_factory, battle_setup) -> Dictionary:
    if sample_factory == null:
        return {"error": "SampleBattleFactory init failed"}
    if battle_setup == null:
        return {"error": "battle_setup is required"}
    var snapshot_result: Dictionary = sample_factory.content_snapshot_paths_for_setup_result(battle_setup)
    if not bool(snapshot_result.get("ok", false)):
        return {"error": str(snapshot_result.get("error_message", "content snapshot path build failed"))}
    return {"paths": snapshot_result.get("data", PackedStringArray())}

func build_loaded_content_index(sample_factory):
    var content_index = BattleContentIndexScript.new()
    var snapshot_paths_payload := build_content_snapshot_paths(sample_factory)
    assert(not snapshot_paths_payload.has("error"), "Content snapshot path build failed: %s" % str(snapshot_paths_payload.get("error", "unknown error")))
    var loaded: bool = content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray()))
    assert(loaded, "Content snapshot load failed: %s" % content_index.last_error_message)
    return content_index

func build_loaded_content_index_for_setup(sample_factory, battle_setup):
    var content_index = BattleContentIndexScript.new()
    var snapshot_paths_payload := build_content_snapshot_paths_for_setup(sample_factory, battle_setup)
    assert(not snapshot_paths_payload.has("error"), "Content snapshot path build failed: %s" % str(snapshot_paths_payload.get("error", "unknown error")))
    var loaded: bool = content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray()))
    assert(loaded, "Content snapshot load failed: %s" % content_index.last_error_message)
    return content_index

func build_initialized_battle(core, content_index, sample_factory, seed: int, battle_setup = null):
    core.service("rng_service").reset(seed)
    core.service("id_factory").reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.service("id_factory").next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
    core.service("battle_initializer").initialize_battle(
        battle_state,
        content_index,
        battle_setup if battle_setup != null else build_sample_setup(sample_factory)
    )
    return battle_state

func find_last_event(event_log: Array, event_type: String):
    for i in range(event_log.size() - 1, -1, -1):
        if event_log[i].event_type == event_type:
            return event_log[i]
    return null

func extract_damage_from_log(event_log: Array, attacker_public_id: String) -> int:
    for ev in event_log:
        if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).begins_with("%s dealt " % attacker_public_id) and not ev.value_changes.is_empty():
            return abs(int(ev.value_changes[0].delta))
    return 0
