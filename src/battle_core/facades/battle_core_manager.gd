extends RefCounted
class_name BattleCoreManager

const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const DeepCopyHelperScript := preload("res://src/shared/deep_copy_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
var _container_factory: Callable = Callable()
var _command_builder = null
var _command_id_factory = null
var _public_snapshot_builder = null
var _container_factory_owner = null
var _sessions: Dictionary = {}
var _session_seq: int = 0
var _event_log_public_snapshot_builder = null
var _container_service = null
var _disposed: bool = false
func create_session(init_payload: Dictionary) -> Dictionary:
    var payload_error = BattleCoreManagerContractHelperScript.validate_create_session_payload(init_payload)
    if payload_error != null:
        return payload_error
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_id := _next_session_id()
    _sync_container_service()
    var create_result = _container_service.create_session_result(session_id, init_payload)
    var session = create_result.get("session", null)
    var response = create_result.get("response", BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager failed to create session"))
    if session == null:
        return response
    var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
    if runtime_error != null:
        if session.has_method("dispose"):
            session.dispose()
        return runtime_error
    _sessions[session_id] = session
    var public_snapshot = _public_snapshot_builder.build_public_snapshot(session.current_battle_state(), session.current_content_index())
    return BattleCoreManagerContractHelperScript.ok({
        "session_id": session_id,
        "public_snapshot": public_snapshot,
        "prebattle_public_teams": DeepCopyHelperScript.copy_value(public_snapshot.get("prebattle_public_teams", [])),
    })

func get_legal_actions(session_id: String, side_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = BattleCoreManagerContractHelperScript.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
    return session.get_legal_actions_result(side_id)

func build_command(input_payload: Dictionary) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if input_payload == null:
        return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "BattleCoreManager.build_command requires input payload")
    var command = _command_builder.build_command(input_payload)
    if command == null:
        return BattleCoreManagerContractHelperScript.service_error(
            _command_builder,
            ErrorCodesScript.INVALID_COMMAND_PAYLOAD,
            "BattleCoreManager failed to build command"
        )
    return BattleCoreManagerContractHelperScript.ok(command)

func run_turn(session_id: String, commands: Array) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = BattleCoreManagerContractHelperScript.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var normalized_commands: Array = []
    for raw_command in commands:
        var command_result = BattleCoreManagerContractHelperScript.normalize_command_input(raw_command)
        if not bool(command_result.get("ok", false)):
            return command_result
        normalized_commands.append(command_result.get("data", null))
    var session = session_result.get("data", null)
    var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
    var run_turn_result = session.run_turn_result(normalized_commands)
    if not bool(run_turn_result.get("ok", false)):
        return run_turn_result
    var turn_failure = BattleCoreManagerContractHelperScript.resolve_turn_failure_result(session)
    if turn_failure != null:
        return turn_failure
    return BattleCoreManagerContractHelperScript.ok({
        "session_id": session_id,
        "public_snapshot": _public_snapshot_builder.build_public_snapshot(session.current_battle_state(), session.current_content_index()),
    })

func get_public_snapshot(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = BattleCoreManagerContractHelperScript.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
    return BattleCoreManagerContractHelperScript.ok(
        _public_snapshot_builder.build_public_snapshot(session.current_battle_state(), session.current_content_index())
    )

func get_event_log_snapshot(session_id: String, from_index: int = 0) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if from_index < 0:
        return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager.get_event_log_snapshot requires from_index >= 0")
    var session_result = BattleCoreManagerContractHelperScript.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
    if runtime_error != null:
        return runtime_error
    var event_log_result = session.get_event_log_snapshot_result()
    if not bool(event_log_result.get("ok", false)):
        return event_log_result
    var event_log: Array = event_log_result.get("data", [])
    var start_index: int = min(from_index, event_log.size())
    var event_snapshots: Array = []
    for event_index in range(start_index, event_log.size()):
        event_snapshots.append(
            _event_log_public_snapshot_builder.build_public_snapshot(event_log[event_index], session.current_battle_state())
        )
    return BattleCoreManagerContractHelperScript.ok({"events": event_snapshots, "total_size": event_log.size()})

func close_session(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    var session_result = BattleCoreManagerContractHelperScript.get_session_result(_sessions, session_id)
    if not bool(session_result.get("ok", false)):
        return session_result
    var session = session_result.get("data", null)
    session.dispose()
    _sessions.erase(session_id)
    return BattleCoreManagerContractHelperScript.ok({"session_id": session_id, "closed": true})

func run_replay(replay_input) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if replay_input == null:
        return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_REPLAY_INPUT, "BattleCoreManager.run_replay requires replay_input")
    _sync_container_service()
    return _container_service.run_replay_result(replay_input)

func active_session_count() -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    return BattleCoreManagerContractHelperScript.ok({"count": _sessions.size()})

func dispose() -> void:
    if _disposed:
        return
    for session in _sessions.values():
        if session != null and session.has_method("dispose"):
            session.dispose()
    _sessions.clear()
    if _command_builder != null:
        _command_builder.id_factory = null
    _disposed = true
    _container_factory = Callable()
    _container_factory_owner = null
    _command_builder = null
    _command_id_factory = null
    _public_snapshot_builder = null
    _event_log_public_snapshot_builder = null
    _container_service = null

func resolve_missing_dependency() -> String:
    if not _container_factory.is_valid():
        return "container_factory"
    if _command_builder == null:
        return "command_builder"
    if _command_id_factory == null:
        return "command_id_factory"
    if _public_snapshot_builder == null:
        return "public_snapshot_builder"
    if _event_log_public_snapshot_builder == null:
        return "event_log_public_snapshot_builder"
    if _container_service == null:
        return "container_service"
    return ""
func _configure_core_ports(container_factory: Callable, command_builder, command_id_factory, public_snapshot_builder, event_log_public_snapshot_builder, container_service, container_factory_owner = null) -> void:
    _container_factory = container_factory
    _command_builder = command_builder
    _command_id_factory = command_id_factory
    _public_snapshot_builder = public_snapshot_builder
    _event_log_public_snapshot_builder = event_log_public_snapshot_builder
    _container_service = container_service
    _container_factory_owner = container_factory_owner
    if _command_builder != null:
        _command_builder.id_factory = _command_id_factory
func _validate_core_dependencies_result() -> Variant:
    if _disposed:
        return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager is disposed")
    return BattleCoreManagerContractHelperScript.dependency_error(resolve_missing_dependency())
func _sync_container_service() -> void:
    _container_service.container_factory = _container_factory
    _container_service.public_snapshot_builder = _public_snapshot_builder
    _container_service.container_factory_owner = _container_factory_owner
func _next_session_id() -> String:
    _session_seq += 1
    return "session_%d" % _session_seq
