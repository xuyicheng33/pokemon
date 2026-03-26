extends RefCounted
class_name BattleCoreManager

const BattleCoreSessionScript := preload("res://src/battle_core/facades/battle_core_session.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")

var composer
var command_builder
var command_id_factory
var public_snapshot_builder

var _sessions: Dictionary = {}
var _session_seq: int = 0

func create_session(init_payload: Dictionary) -> Dictionary:
    assert(init_payload != null, "BattleCoreManager.create_session requires input payload")
    assert(init_payload.has("battle_setup"), "BattleCoreManager.create_session requires battle_setup")
    assert(init_payload.has("content_snapshot_paths"), "BattleCoreManager.create_session requires content_snapshot_paths")
    _assert_core_dependencies()
    var container = _compose_container_or_fail()
    var session_id := _next_session_id()
    var battle_seed: int = int(init_payload.get("battle_seed", 0))
    container.id_factory.reset()
    container.rng_service.reset(battle_seed)
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(init_payload["content_snapshot_paths"])
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = session_id
    battle_state.seed = battle_seed
    battle_state.rng_stream_index = container.rng_service.get_stream_index()
    container.battle_initializer.initialize_battle(battle_state, content_index, init_payload["battle_setup"])
    var session = BattleCoreSessionScript.new()
    session.session_id = session_id
    session.container = container
    session.battle_state = battle_state
    session.content_index = content_index
    _sessions[session_id] = session
    var public_snapshot = public_snapshot_builder.build_public_snapshot(battle_state, content_index)
    return {
        "session_id": session_id,
        "public_snapshot": public_snapshot,
        "prebattle_public_teams": public_snapshot.get("prebattle_public_teams", []),
    }

func get_legal_actions(session_id: String, side_id: String):
    _assert_core_dependencies()
    var session = _get_session_or_fail(session_id)
    return session.container.legal_action_service.get_legal_actions(session.battle_state, side_id, session.content_index)

func build_command(input_payload: Dictionary):
    _assert_core_dependencies()
    return command_builder.build_command(input_payload)

func run_turn(session_id: String, commands: Array) -> Dictionary:
    _assert_core_dependencies()
    var session = _get_session_or_fail(session_id)
    session.container.turn_loop_controller.run_turn(session.battle_state, session.content_index, commands)
    return {
        "session_id": session_id,
        "public_snapshot": public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index),
    }

func get_public_snapshot(session_id: String) -> Dictionary:
    _assert_core_dependencies()
    var session = _get_session_or_fail(session_id)
    return public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index)

func close_session(session_id: String) -> void:
    _assert_core_dependencies()
    assert(not session_id.is_empty(), "BattleCoreManager.close_session requires non-empty session_id")
    var session = _sessions.get(session_id, null)
    assert(session != null, "BattleCoreManager unknown battle session: %s" % session_id)
    session.dispose()
    _sessions.erase(session_id)

func run_replay(replay_input) -> Dictionary:
    _assert_core_dependencies()
    var temp_container = _compose_container_or_fail()
    var replay_result: Dictionary = temp_container.replay_runner.run_replay_with_context(replay_input)
    var replay_output = replay_result["replay_output"]
    var public_snapshot = public_snapshot_builder.build_public_snapshot(replay_output.final_battle_state, replay_result["content_index"])
    temp_container.dispose()
    return {
        "replay_output": replay_output,
        "public_snapshot": public_snapshot,
    }

func active_session_count() -> int:
    return _sessions.size()

func dispose() -> void:
    for session in _sessions.values():
        if session != null and session.has_method("dispose"):
            session.dispose()
    _sessions.clear()
    if command_builder != null:
        command_builder.id_factory = null
    composer = null
    command_builder = null
    command_id_factory = null
    public_snapshot_builder = null

func resolve_missing_dependency() -> String:
    if composer == null:
        return "composer"
    if command_builder == null:
        return "command_builder"
    if command_id_factory == null:
        return "command_id_factory"
    if public_snapshot_builder == null:
        return "public_snapshot_builder"
    return ""

func _assert_core_dependencies() -> void:
    var missing_dependency := resolve_missing_dependency()
    assert(missing_dependency.is_empty(), "BattleCoreManager missing dependency: %s" % missing_dependency)

func _get_session_or_fail(session_id: String):
    assert(not session_id.is_empty(), "BattleCoreManager requires non-empty session_id")
    var session = _sessions.get(session_id, null)
    assert(session != null, "BattleCoreManager unknown battle session: %s" % session_id)
    return session

func _compose_container_or_fail():
    assert(composer != null and composer.has_method("compose"), "BattleCoreManager requires composer.compose")
    var container = composer.compose()
    assert(container != null, "BattleCoreManager failed to compose battle core container")
    return container

func _next_session_id() -> String:
    _session_seq += 1
    return "session_%d" % _session_seq
