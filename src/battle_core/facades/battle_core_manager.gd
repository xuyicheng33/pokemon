extends RefCounted
class_name BattleCoreManager

const BattleCoreSessionScript := preload("res://src/battle_core/facades/battle_core_session.gd")
const EventLogPublicSnapshotBuilderScript := preload("res://src/battle_core/facades/event_log_public_snapshot_builder.gd")
const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const BattleCoreManagerContainerServiceScript := preload("res://src/battle_core/facades/battle_core_manager_container_service.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _container_factory: Callable = Callable()
var _command_builder = null
var _command_id_factory = null
var _public_snapshot_builder = null
var _container_factory_owner = null

var _sessions: Dictionary = {}
var _session_seq: int = 0
var _event_log_public_snapshot_builder = EventLogPublicSnapshotBuilderScript.new()
var _contract_helper = BattleCoreManagerContractHelperScript.new()
var _container_service = BattleCoreManagerContainerServiceScript.new()
var _disposed: bool = false

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
    return session.get_legal_actions_result(side_id)

func build_command(input_payload: Dictionary) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    if input_payload == null:
        return _contract_helper.error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "BattleCoreManager.build_command requires input payload")
    var command = _command_builder.build_command(input_payload)
    if command == null:
        return _contract_helper.service_error(
            _command_builder,
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
    var run_turn_result = session.run_turn_result(normalized_commands)
    if not bool(run_turn_result.get("ok", false)):
        return run_turn_result
    var turn_failure = _contract_helper.resolve_turn_failure_result(session)
    if turn_failure != null:
        return turn_failure
    return _contract_helper.ok({"session_id": session_id, "public_snapshot": _public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index)})

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
    return _contract_helper.ok(_public_snapshot_builder.build_public_snapshot(session.battle_state, session.content_index))

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
    var event_log_result = session.get_event_log_snapshot_result()
    if not bool(event_log_result.get("ok", false)):
        return event_log_result
    var event_log: Array = event_log_result.get("data", [])
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
    return ""
func _configure_core_ports(container_factory: Callable, command_builder, command_id_factory, public_snapshot_builder, container_factory_owner = null) -> void:
    _container_factory = container_factory
    _command_builder = command_builder
    _command_id_factory = command_id_factory
    _public_snapshot_builder = public_snapshot_builder
    _container_factory_owner = container_factory_owner
    if _command_builder != null:
        _command_builder.id_factory = _command_id_factory
func _override_container_factory_for_test(container_factory: Callable, container_factory_owner = null) -> void:
    _container_factory = container_factory
    _container_factory_owner = container_factory_owner
func _replace_public_snapshot_builder_for_test(public_snapshot_builder) -> void:
    _public_snapshot_builder = public_snapshot_builder
func _inject_session_for_test(session_id: String, session) -> void:
    _sessions[session_id] = session
func _debug_session(session_id: String):
    return _sessions.get(session_id, null)
func _shared_content_snapshot_cache_for_test():
    if _container_factory_owner == null or _container_factory_owner.composer == null:
        return null
    return _container_factory_owner.composer.shared_content_snapshot_cache()
func _validate_core_dependencies_result():
    if _disposed:
        return _contract_helper.error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "BattleCoreManager is disposed")
    return _contract_helper.dependency_error(resolve_missing_dependency())
func _sync_container_service() -> void:
    _container_service.container_factory = _container_factory
    _container_service.contract_helper = _contract_helper
    _container_service.public_snapshot_builder = _public_snapshot_builder
    _container_service.container_factory_owner = _container_factory_owner
func _next_session_id() -> String:
    _session_seq += 1
    return "session_%d" % _session_seq
