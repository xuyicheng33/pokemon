extends RefCounted
class_name BattleCoreManager

const BattleCoreSessionScript := preload("res://src/battle_core/facades/battle_core_session.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const EventLogPublicSnapshotBuilderScript := preload("res://src/battle_core/facades/event_log_public_snapshot_builder.gd")
const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var container_factory: Callable = Callable()
var command_builder
var command_id_factory
var public_snapshot_builder
var _container_factory_owner = null

var _sessions: Dictionary = {}
var _session_seq: int = 0
var _event_log_public_snapshot_builder = EventLogPublicSnapshotBuilderScript.new()
var _contract_helper = BattleCoreManagerContractHelperScript.new()

func create_session(init_payload: Dictionary) -> Dictionary:
    var payload_error = _contract_helper.validate_create_session_payload(init_payload)
    if payload_error != null:
        return payload_error
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var compose_result = _compose_container_result()
    if not bool(compose_result.get("ok", false)):
        return compose_result
    var container = compose_result.get("data", null)
    var session_id := _next_session_id()
    var battle_seed: int = int(init_payload.get("battle_seed", 0))
    container.id_factory.reset()
    container.rng_service.reset(battle_seed)
    var content_index = BattleContentIndexScript.new()
    if not content_index.load_snapshot(init_payload["content_snapshot_paths"]):
        container.dispose()
        return _contract_helper.error(
            content_index.last_error_code if content_index.last_error_code != null else ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
            content_index.last_error_message if not content_index.last_error_message.is_empty() else "BattleCoreManager failed to load content snapshot"
        )
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = session_id
    battle_state.seed = battle_seed
    battle_state.rng_stream_index = container.rng_service.get_stream_index()
    if not container.battle_initializer.initialize_battle(battle_state, content_index, init_payload["battle_setup"]):
        container.dispose()
        return _contract_helper.error(
            container.battle_initializer.last_error_code if container.battle_initializer.last_error_code != null else ErrorCodesScript.INVALID_BATTLE_SETUP,
            container.battle_initializer.last_error_message if not container.battle_initializer.last_error_message.is_empty() else "BattleCoreManager failed to initialize battle"
        )
    var session = BattleCoreSessionScript.new()
    session.session_id = session_id
    session.container = container
    session.battle_state = battle_state
    session.content_index = content_index
    _sessions[session_id] = session
    var public_snapshot = public_snapshot_builder.build_public_snapshot(battle_state, content_index)
    return _contract_helper.ok({
        "session_id": session_id,
        "public_snapshot": public_snapshot,
        "prebattle_public_teams": public_snapshot.get("prebattle_public_teams", []),
    })

func get_legal_actions(session_id: String, side_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = _get_session_result(session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var legal_actions = session.container.legal_action_service.get_legal_actions(session.battle_state, side_id, session.content_index)
    if legal_actions == null:
        return _contract_helper.service_error(
            session.container.legal_action_service,
            ErrorCodesScript.INVALID_STATE_CORRUPTION,
            "BattleCoreManager failed to build legal action set"
        )
    return _contract_helper.ok(legal_actions)

func build_command(input_payload: Dictionary) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if input_payload == null:
        return _contract_helper.error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "BattleCoreManager.build_command requires input payload")
    var command = command_builder.build_command(input_payload)
    if command == null:
        return _contract_helper.service_error(
            command_builder,
            ErrorCodesScript.INVALID_COMMAND_PAYLOAD,
            "BattleCoreManager failed to build command"
        )
    return _contract_helper.ok(command)

func run_turn(session_id: String, commands: Array) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = _get_session_result(session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var normalized_commands: Array = []
    for raw_command in commands:
        var command_result = _contract_helper.normalize_command_input(raw_command)
        if not bool(command_result.get("ok", false)):
            return command_result
        normalized_commands.append(command_result.get("data", null))
    var session = session_result.get("data", null)
    session.container.turn_loop_controller.run_turn(session.battle_state, session.content_index, normalized_commands)
    return _contract_helper.ok({
        "session_id": session_id,
        "public_snapshot": public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index),
    })

func get_public_snapshot(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = _get_session_result(session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    return _contract_helper.ok(public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index))

func get_event_log_snapshot(session_id: String, from_index: int = 0) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if from_index < 0:
        return _contract_helper.error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.get_event_log_snapshot requires from_index >= 0")
    var session_result = _get_session_result(session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var event_log: Array = session.container.battle_logger.snapshot()
    var start_index: int = min(from_index, event_log.size())
    var event_snapshots: Array = []
    for event_index in range(start_index, event_log.size()):
        event_snapshots.append(_event_log_public_snapshot_builder.build_public_snapshot(event_log[event_index], session.battle_state))
    return _contract_helper.ok({
        "events": event_snapshots,
        "total_size": event_log.size(),
    })

func close_session(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = _get_session_result(session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    session.dispose()
    _sessions.erase(session_id)
    return _contract_helper.ok({"session_id": session_id, "closed": true})

func run_replay(replay_input) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if replay_input == null:
        return _contract_helper.error(ErrorCodesScript.INVALID_REPLAY_INPUT, "BattleCoreManager.run_replay requires replay_input")
    var compose_result = _compose_container_result()
    if not bool(compose_result.get("ok", false)):
        return compose_result
    var temp_container = compose_result.get("data", null)
    var replay_result: Dictionary = temp_container.replay_runner.run_replay_with_context(replay_input)
    var internal_replay_output = replay_result.get("replay_output", null)
    if internal_replay_output == null:
        var error_result = _contract_helper.service_error(
            temp_container.replay_runner,
            ErrorCodesScript.INVALID_REPLAY_INPUT,
            "BattleCoreManager failed to run replay"
        )
        temp_container.dispose()
        return error_result
    var public_snapshot = public_snapshot_builder.build_public_snapshot(internal_replay_output.final_battle_state, replay_result["content_index"])
    var replay_output = internal_replay_output.clone_without_runtime_state()
    temp_container.dispose()
    return _contract_helper.ok({
        "replay_output": replay_output,
        "public_snapshot": public_snapshot,
    })

func active_session_count() -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    return _contract_helper.ok({"count": _sessions.size()})

func dispose() -> void:
    for session in _sessions.values():
        if session != null and session.has_method("dispose"):
            session.dispose()
    _sessions.clear()
    if command_builder != null:
        command_builder.id_factory = null
    container_factory = Callable()
    _container_factory_owner = null
    command_builder = null
    command_id_factory = null
    public_snapshot_builder = null
    _event_log_public_snapshot_builder = null
    _contract_helper = null

func resolve_missing_dependency() -> String:
    if not container_factory.is_valid():
        return "container_factory"
    if command_builder == null:
        return "command_builder"
    if command_id_factory == null:
        return "command_id_factory"
    if public_snapshot_builder == null:
        return "public_snapshot_builder"
    if _event_log_public_snapshot_builder == null:
        return "event_log_public_snapshot_builder"
    return ""

func _validate_core_dependencies_result():
    return _contract_helper.dependency_error(resolve_missing_dependency())

func _get_session_result(session_id: String) -> Dictionary:
    if session_id.is_empty():
        return _contract_helper.error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager requires non-empty session_id")
    var session = _sessions.get(session_id, null)
    if session == null:
        return _contract_helper.error(ErrorCodesScript.INVALID_SESSION, "BattleCoreManager unknown battle session: %s" % session_id)
    return _contract_helper.ok(session)

func _compose_container_result() -> Dictionary:
    if not container_factory.is_valid():
        return _contract_helper.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager requires container_factory")
    var container = container_factory.call()
    if container != null:
        return _contract_helper.ok(container)
    var composer = _container_factory_owner.composer if _container_factory_owner != null else null
    if composer != null:
        return _contract_helper.error(
            composer.last_error_code if composer.last_error_code != null else ErrorCodesScript.INVALID_COMPOSITION,
            composer.last_error_message if not composer.last_error_message.is_empty() else "BattleCoreManager failed to compose battle core container"
        )
    return _contract_helper.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager failed to compose battle core container")

func _next_session_id() -> String:
    _session_seq += 1
    return "session_%d" % _session_seq
