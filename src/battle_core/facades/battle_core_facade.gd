extends RefCounted
class_name BattleCoreFacade

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")

var id_factory
var rng_service
var battle_initializer
var legal_action_service
var command_builder
var turn_loop_controller
var replay_runner

var _sessions: Dictionary = {}

func initialize_battle(input_payload: Dictionary) -> Dictionary:
    assert(input_payload != null, "BattleCoreFacade.initialize_battle requires input payload")
    assert(input_payload.has("battle_setup"), "BattleCoreFacade.initialize_battle requires battle_setup")
    assert(input_payload.has("content_snapshot_paths"), "BattleCoreFacade.initialize_battle requires content_snapshot_paths")
    _assert_core_dependencies()
    var battle_seed: int = int(input_payload.get("battle_seed", 0))
    id_factory.reset()
    rng_service.reset(battle_seed)
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(input_payload["content_snapshot_paths"])
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = id_factory.next_id("battle")
    battle_state.seed = battle_seed
    battle_state.rng_stream_index = rng_service.get_stream_index()
    battle_initializer.initialize_battle(battle_state, content_index, input_payload["battle_setup"])
    _sessions[battle_state.battle_id] = {
        "battle_state": battle_state,
        "content_index": content_index,
    }
    return {
        "battle_id": battle_state.battle_id,
        "public_snapshot": _build_public_snapshot_from_state(battle_state),
    }

func get_legal_actions(battle_id: String, side_id: String):
    _assert_core_dependencies()
    var session = _get_session_or_fail(battle_id)
    return legal_action_service.get_legal_actions(session["battle_state"], side_id, session["content_index"])

func build_command(input_payload: Dictionary):
    _assert_core_dependencies()
    return command_builder.build_command(input_payload)

func run_turn(battle_id: String, commands: Array) -> Dictionary:
    _assert_core_dependencies()
    var session = _get_session_or_fail(battle_id)
    var battle_state = session["battle_state"]
    turn_loop_controller.run_turn(battle_state, session["content_index"], commands)
    return {
        "battle_id": battle_id,
        "public_snapshot": _build_public_snapshot_from_state(battle_state),
    }

func run_replay(replay_input) -> Dictionary:
    _assert_core_dependencies()
    var replay_output = replay_runner.run_replay(replay_input)
    return {
        "replay_output": replay_output,
        "public_snapshot": _build_public_snapshot_from_state(replay_output.final_battle_state),
    }

func build_public_snapshot(battle_id: String) -> Dictionary:
    var session = _get_session_or_fail(battle_id)
    return _build_public_snapshot_from_state(session["battle_state"])

func close_battle(battle_id: String) -> void:
    _sessions.erase(battle_id)

func dispose() -> void:
    _sessions.clear()

func resolve_missing_dependency() -> String:
    if id_factory == null:
        return "id_factory"
    if rng_service == null:
        return "rng_service"
    if battle_initializer == null:
        return "battle_initializer"
    if legal_action_service == null:
        return "legal_action_service"
    if command_builder == null:
        return "command_builder"
    if turn_loop_controller == null:
        return "turn_loop_controller"
    if replay_runner == null:
        return "replay_runner"
    return ""

func _assert_core_dependencies() -> void:
    var missing_dependency := resolve_missing_dependency()
    assert(missing_dependency.is_empty(), "BattleCoreFacade missing dependency: %s" % missing_dependency)

func _get_session_or_fail(battle_id: String) -> Dictionary:
    assert(not battle_id.is_empty(), "BattleCoreFacade requires non-empty battle_id")
    var session: Variant = _sessions.get(battle_id, null)
    assert(session != null, "BattleCoreFacade unknown battle session: %s" % battle_id)
    return session

func _build_public_snapshot_from_state(battle_state) -> Dictionary:
    assert(battle_state != null, "BattleCoreFacade requires battle_state to build public snapshot")
    var side_models: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        var bench_public_ids: Array[String] = []
        for bench_unit_id in side_state.bench_order:
            var bench_unit = side_state.find_unit(str(bench_unit_id))
            if bench_unit != null:
                bench_public_ids.append(bench_unit.public_id)
        side_models.append({
            "side_id": side_state.side_id,
            "active_public_id": active_unit.public_id if active_unit != null else null,
            "active_hp": active_unit.current_hp if active_unit != null else null,
            "active_mp": active_unit.current_mp if active_unit != null else null,
            "bench_public_ids": bench_public_ids,
        })
    return {
        "battle_id": battle_state.battle_id,
        "turn_index": battle_state.turn_index,
        "phase": battle_state.phase,
        "field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
        "sides": side_models,
        "battle_result": battle_state.battle_result.to_stable_dict() if battle_state.battle_result != null else null,
    }
