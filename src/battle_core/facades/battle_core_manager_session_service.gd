extends RefCounted
class_name BattleCoreManagerSessionService

const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const DeepCopyHelperScript := preload("res://src/shared/deep_copy_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var sessions: Dictionary = {}
var public_snapshot_builder: BattleCorePublicSnapshotBuilder = null

func configure_session_ports(
	next_sessions: Dictionary,
	next_public_snapshot_builder: BattleCorePublicSnapshotBuilder
) -> void:
	sessions = next_sessions
	public_snapshot_builder = next_public_snapshot_builder

func create_session_result(container_service: BattleCoreManagerContainerService, session_id: String, init_payload: Dictionary) -> Dictionary:
	var create_result = container_service.create_session_result(session_id, init_payload)
	if not bool(create_result.get("ok", false)):
		return create_result
	var create_payload: Dictionary = create_result.get("data", {})
	var session = create_payload.get("session", null)
	var resolved_session_id := String(create_payload.get("session_id", session_id))
	if session == null:
		return BattleCoreManagerContractHelperScript.error(
			ErrorCodesScript.INVALID_COMPOSITION,
			"BattleCoreManager failed to create session"
		)
	var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
	if runtime_error != null:
		if session.has_method("dispose"):
			session.dispose()
		return runtime_error
	sessions[resolved_session_id] = session
	var public_snapshot = public_snapshot_builder.build_public_snapshot(
		session.current_battle_state(),
		session.current_content_index()
	)
	return BattleCoreManagerContractHelperScript.ok({
		"session_id": resolved_session_id,
		"public_snapshot": public_snapshot,
		"prebattle_public_teams": DeepCopyHelperScript.copy_value(public_snapshot.get("prebattle_public_teams", [])),
	})

func get_legal_actions_result(session_id: String, side_id: String) -> Dictionary:
	var session_result = BattleCoreManagerContractHelperScript.get_session_result(sessions, session_id)
	if not bool(session_result.get("ok", false)):
		return session_result
	var session = session_result.get("data", null)
	var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
	if runtime_error != null:
		return runtime_error
	return session.get_legal_actions_result(side_id)

func run_turn_result(session_id: String, commands: Array) -> Dictionary:
	var session_result = BattleCoreManagerContractHelperScript.get_session_result(sessions, session_id)
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
	var session_run_turn_result = session.run_turn_result(normalized_commands)
	if not bool(session_run_turn_result.get("ok", false)):
		return session_run_turn_result
	runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
	if runtime_error != null:
		return runtime_error
	var turn_failure = BattleCoreManagerContractHelperScript.resolve_turn_failure_result(session)
	if turn_failure != null:
		return turn_failure
	return BattleCoreManagerContractHelperScript.ok({
		"session_id": session_id,
		"public_snapshot": public_snapshot_builder.build_public_snapshot(
			session.current_battle_state(),
			session.current_content_index()
		),
	})

func get_public_snapshot_result(session_id: String) -> Dictionary:
	var session_result = BattleCoreManagerContractHelperScript.get_session_result(sessions, session_id)
	if not bool(session_result.get("ok", false)):
		return session_result
	var session = session_result.get("data", null)
	var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
	if runtime_error != null:
		return runtime_error
	return BattleCoreManagerContractHelperScript.ok(
		public_snapshot_builder.build_public_snapshot(
			session.current_battle_state(),
			session.current_content_index()
		)
	)

func get_event_log_snapshot_result(session_id: String, from_index: int = 0) -> Dictionary:
	if from_index < 0:
		return BattleCoreManagerContractHelperScript.error(
			ErrorCodesScript.INVALID_MANAGER_REQUEST,
			"BattleCoreManager.get_event_log_snapshot requires from_index >= 0"
		)
	var session_result = BattleCoreManagerContractHelperScript.get_session_result(sessions, session_id)
	if not bool(session_result.get("ok", false)):
		return session_result
	var session = session_result.get("data", null)
	var event_log_result = session.get_event_log_snapshot_result()
	if not bool(event_log_result.get("ok", false)):
		return event_log_result
	var event_log: Array = event_log_result.get("data", [])
	var start_index: int = min(from_index, event_log.size())
	var event_snapshots: Array = []
	for event_index in range(start_index, event_log.size()):
		event_snapshots.append(
			public_snapshot_builder.build_event_public_snapshot(
				event_log[event_index],
				session.current_battle_state()
			)
		)
	return BattleCoreManagerContractHelperScript.ok({"events": event_snapshots, "total_size": event_log.size()})

func close_session_result(session_id: String) -> Dictionary:
	var session_result = BattleCoreManagerContractHelperScript.get_session_result(sessions, session_id)
	if not bool(session_result.get("ok", false)):
		return session_result
	var session = session_result.get("data", null)
	session.dispose()
	sessions.erase(session_id)
	return BattleCoreManagerContractHelperScript.ok({"session_id": session_id, "closed": true})
