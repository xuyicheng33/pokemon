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
        if core.get(service_name) == null:
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
    var required_ports: Array[String] = [
        "composer",
        "command_builder",
        "command_id_factory",
        "public_snapshot_builder",
    ]
    for port_name in required_ports:
        if manager.get(port_name) == null:
            return {"error": "missing manager port: %s" % port_name}
    _manager_pool.append(manager)
    return {"manager": manager}

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

func build_loaded_content_index(sample_factory):
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())
    return content_index

func build_initialized_battle(core, content_index, sample_factory, seed: int):
    core.rng_service.reset(seed)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, sample_factory.build_sample_setup())
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
