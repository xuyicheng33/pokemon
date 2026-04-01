extends RefCounted
class_name BattleCoreManager

const BattleCoreSessionScript := preload("res://src/battle_core/facades/battle_core_session.gd")
const EventLogPublicSnapshotBuilderScript := preload("res://src/battle_core/facades/event_log_public_snapshot_builder.gd")
const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const BattleCoreManagerContainerServiceScript := preload("res://src/battle_core/facades/battle_core_manager_container_service.gd")
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
var _container_service = BattleCoreManagerContainerServiceScript.new()

func create_session(init_payload: Dictionary) -> Dictionary:
    var payload_error = _contract_helper.validate_create_session_payload(init_payload)
    if payload_error != null:
        return payload_error
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_id := _next_session_id()
    _sync_container_service()
    var create_result = _container_service.create_session_result(session_id, init_payload)
    var session = create_result.get("session", null)
    var response = create_result.get("response", _contract_helper.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager failed to create session"))
    if session == null:
        return response
    _sessions[session_id] = session
    return response

func get_legal_actions(session_id: String, side_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = _contract_helper.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var runtime_error = _contract_helper.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
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
    var session_result = _contract_helper.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var normalized_commands: Array = []
    for raw_command in commands:
        var command_result = _contract_helper.normalize_command_input(raw_command)
        if not bool(command_result.get("ok", false)):
            return command_result
        normalized_commands.append(command_result.get("data", null))
    var session = session_result.get("data", null)
    var runtime_error = _contract_helper.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
    session.container.turn_loop_controller.run_turn(session.battle_state, session.content_index, normalized_commands)
    var turn_failure = _contract_helper.resolve_turn_failure_result(session)
    if turn_failure != null:
        return turn_failure
    return _contract_helper.ok({"session_id": session_id, "public_snapshot": public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index)})

func get_public_snapshot(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = _contract_helper.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var runtime_error = _contract_helper.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
    return _contract_helper.ok(public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index))

func get_event_log_snapshot(session_id: String, from_index: int = 0) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if from_index < 0:
        return _contract_helper.error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.get_event_log_snapshot requires from_index >= 0")
    var session_result = _contract_helper.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var runtime_error = _contract_helper.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
    var event_log: Array = session.container.battle_logger.snapshot()
    var start_index: int = min(from_index, event_log.size())
    var event_snapshots: Array = []
    for event_index in range(start_index, event_log.size()):
        event_snapshots.append(_event_log_public_snapshot_builder.build_public_snapshot(event_log[event_index], session.battle_state))
    return _contract_helper.ok({"events": event_snapshots, "total_size": event_log.size()})

func close_session(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = _contract_helper.get_session_result(_sessions, session_id)
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
    _sync_container_service()
    return _container_service.run_replay_result(replay_input)

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
    _container_service = null
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

func _sync_container_service() -> void:
    _container_service.container_factory = container_factory
    _container_service.contract_helper = _contract_helper
    _container_service.public_snapshot_builder = public_snapshot_builder
    _container_service.container_factory_owner = _container_factory_owner

func _next_session_id() -> String:
    _session_seq += 1
    return "session_%d" % _session_seq
