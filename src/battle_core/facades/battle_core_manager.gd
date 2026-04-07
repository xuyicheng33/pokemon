extends RefCounted
class_name BattleCoreManager

const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const BattleCoreManagerSessionServiceScript := preload("res://src/battle_core/facades/battle_core_manager_session_service.gd")
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
var _session_service = BattleCoreManagerSessionServiceScript.new()
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
    return _session_service.create_session_result(_container_service, session_id, init_payload)

func get_legal_actions(session_id: String, side_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    return _session_service.get_legal_actions_result(session_id, side_id)

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
    return _session_service.run_turn_result(session_id, commands)

func get_public_snapshot(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    return _session_service.get_public_snapshot_result(session_id)

func get_event_log_snapshot(session_id: String, from_index: int = 0) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    return _session_service.get_event_log_snapshot_result(session_id, from_index)

func close_session(session_id: String) -> Dictionary:
    var dependency_error = _validate_core_dependencies_result()
    if dependency_error != null:
        return dependency_error
    return _session_service.close_session_result(session_id)

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
    _session_service.configure_session_ports(_sessions, null, null)

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
    _session_service.configure_session_ports(
        _sessions,
        _public_snapshot_builder,
        _event_log_public_snapshot_builder
    )
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
