extends RefCounted
class_name SandboxSessionCommandService

const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const SIDE_ORDER := ["P1", "P2"]

var selection_adapter: PlayerSelectionAdapter = PlayerSelectionAdapterScript.new()
var _launch_config_helper: BattleSandboxLaunchConfig = BattleSandboxLaunchConfigScript.new()

func primary_side_id() -> String:
	return SIDE_ORDER[0]

func advance_until_manual_or_finished(state: SandboxSessionState, policy_driver) -> Dictionary:
	if policy_driver == null:
		return ResultEnvelopeHelperScript.ok({"command_steps": state.command_steps})
	return policy_driver.advance_until_manual_or_finished(state, self)

func fetch_legal_actions_for_side(state: SandboxSessionState, side_id: String) -> Dictionary:
	var normalized_side_id = str(side_id).strip_edges()
	if normalized_side_id.is_empty():
		return ResultEnvelopeHelperScript.error(null, "side_id is required")
	if state.is_demo_mode:
		return ResultEnvelopeHelperScript.error(null, "demo mode does not expose legal actions")
	if state.manager == null or str(state.session_id).strip_edges().is_empty():
		return ResultEnvelopeHelperScript.error(null, "manual scene has no active session")
	return refresh_legal_actions_for_side(state, normalized_side_id)

func refresh_legal_actions_for_side(state: SandboxSessionState, side_id: String) -> Dictionary:
	if side_id.is_empty():
		return ResultEnvelopeHelperScript.ok(null)
	var legal_actions_unwrap := ResultEnvelopeHelperScript.unwrap_ok(
		state.manager.get_legal_actions(state.session_id, side_id),
		"get_legal_actions(%s)" % side_id
	)
	if not bool(legal_actions_unwrap.get("ok", false)):
		return legal_actions_unwrap
	state.legal_actions_by_side[side_id] = legal_actions_unwrap.get("data", null)
	return legal_actions_unwrap

func submit_action(
	state: SandboxSessionState,
	selected_action: Dictionary,
	policy_driver,
	command_source: String = "manual",
	allow_policy_progression: bool = true
) -> Dictionary:
	if state.is_demo_mode:
		return ResultEnvelopeHelperScript.error(null, "demo mode does not accept manual actions")
	if state.startup_failed:
		return ResultEnvelopeHelperScript.error(null, "battle sandbox is in failed state")
	if has_battle_result(state):
		return ResultEnvelopeHelperScript.error(null, "battle already finished")
	var side_id = str(state.current_side_to_select).strip_edges()
	if side_id.is_empty():
		return ResultEnvelopeHelperScript.error(null, "no side is waiting for selection")
	var legal_actions = state.legal_actions_by_side.get(side_id, null)
	var actor_public_id = str(PropertyAccessHelperScript.read_property(legal_actions, "actor_public_id", "")).strip_edges()
	if actor_public_id.is_empty():
		return ResultEnvelopeHelperScript.error(null, "missing actor_public_id for side %s" % side_id)
	var action_payload: Dictionary = selected_action.duplicate(true)
	action_payload["side_id"] = side_id
	action_payload["actor_public_id"] = actor_public_id
	action_payload["turn_index"] = int(state.public_snapshot.get("turn_index", 1))
	action_payload["command_source"] = command_source
	var command_payload: Dictionary = selection_adapter.build_player_payload(action_payload)
	var command_unwrap: Dictionary = ResultEnvelopeHelperScript.unwrap_ok(
		state.manager.build_command(command_payload),
		"build_command(%s)" % side_id
	)
	if not bool(command_unwrap.get("ok", false)):
		fail_runtime(state, str(command_unwrap.get("error_message", "Battle sandbox failed to build command")))
		return command_unwrap
	state.command_steps += 1
	state.pending_commands[side_id] = command_unwrap.get("data", null)
	if side_id == primary_side_id():
		state.current_side_to_select = SIDE_ORDER[1]
		var refresh_unwrap: Dictionary = refresh_legal_actions_for_side(state, state.current_side_to_select)
		if not bool(refresh_unwrap.get("ok", false)):
			fail_runtime(state, str(refresh_unwrap.get("error_message", "Battle sandbox failed to refresh legal actions")))
			return refresh_unwrap
		if allow_policy_progression:
			var policy_progress_result: Dictionary = advance_until_manual_or_finished(state, policy_driver)
			if not bool(policy_progress_result.get("ok", false)):
				return policy_progress_result
		return ResultEnvelopeHelperScript.ok({
			"side_id": side_id,
			"pending_commands": state.pending_commands.size(),
			"current_side_to_select": state.current_side_to_select,
			"command_steps": state.command_steps,
		})
	return _run_pending_turn(state, policy_driver, allow_policy_progression)

func has_battle_result(state: SandboxSessionState) -> bool:
	var battle_result = state.public_snapshot.get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func fail_runtime(state: SandboxSessionState, message: String) -> void:
	if message.is_empty():
		return
	state.error_message = message
	state.startup_failed = true
	printerr("BATTLE_SANDBOX_FAILED: %s" % message)

func refresh_session_snapshot_and_logs(state: SandboxSessionState, from_index: int) -> String:
	var snapshot_unwrap: Dictionary = ResultEnvelopeHelperScript.unwrap_ok(
		state.manager.get_public_snapshot(state.session_id),
		"get_public_snapshot(%s)" % state.session_id
	)
	if not bool(snapshot_unwrap.get("ok", false)):
		return str(snapshot_unwrap.get("error_message", "Battle sandbox failed to refresh public_snapshot"))
	state.public_snapshot = snapshot_unwrap.get("data", {})
	var event_log_unwrap: Dictionary = ResultEnvelopeHelperScript.unwrap_ok(
		state.manager.get_event_log_snapshot(state.session_id, from_index),
		"get_event_log_snapshot(%s)" % state.session_id
	)
	if not bool(event_log_unwrap.get("ok", false)):
		return str(event_log_unwrap.get("error_message", "Battle sandbox failed to refresh event log"))
	state.event_log_buffer.apply_event_log_snapshot(
		state.public_snapshot,
		from_index,
		event_log_unwrap.get("data", {}),
		_launch_config_helper.build_summary_context(state.launch_config, state.side_control_modes, state.command_steps)
	)
	state.sync_event_log_state()
	return ""

func _run_pending_turn(state: SandboxSessionState, policy_driver, allow_policy_progression: bool) -> Dictionary:
	var commands: Array = []
	for side_id in SIDE_ORDER:
		if not state.pending_commands.has(side_id):
			return ResultEnvelopeHelperScript.error(null, "missing pending command for side %s" % side_id)
		commands.append(state.pending_commands.get(side_id, null))
	var from_index: int = state.event_log_buffer.event_log_cursor
	var run_turn_unwrap: Dictionary = ResultEnvelopeHelperScript.unwrap_ok(
		state.manager.run_turn(state.session_id, commands),
		"run_turn(%s)" % state.session_id
	)
	if not bool(run_turn_unwrap.get("ok", false)):
		fail_runtime(state, str(run_turn_unwrap.get("error_message", "Battle sandbox run_turn failed")))
		return run_turn_unwrap
	state.pending_commands.clear()
	state.legal_actions_by_side.clear()
	state.current_side_to_select = ""
	var refresh_error = refresh_session_snapshot_and_logs(state, from_index)
	if not refresh_error.is_empty():
		fail_runtime(state, refresh_error)
		return ResultEnvelopeHelperScript.error(null, refresh_error)
	if not has_battle_result(state):
		state.current_side_to_select = primary_side_id()
		var legal_unwrap: Dictionary = refresh_legal_actions_for_side(state, state.current_side_to_select)
		if not bool(legal_unwrap.get("ok", false)):
			fail_runtime(state, str(legal_unwrap.get("error_message", "Battle sandbox failed to refresh next turn legal actions")))
			return legal_unwrap
		if allow_policy_progression:
			var policy_progress_result: Dictionary = advance_until_manual_or_finished(state, policy_driver)
			if not bool(policy_progress_result.get("ok", false)):
				return policy_progress_result
	return ResultEnvelopeHelperScript.ok({
		"event_log_cursor": state.event_log_buffer.event_log_cursor,
		"battle_finished": has_battle_result(state),
		"event_delta": state.event_log_buffer.last_event_delta.duplicate(true),
		"public_snapshot": state.public_snapshot.duplicate(true),
		"current_side_to_select": state.current_side_to_select,
		"battle_summary": state.event_log_buffer.battle_summary.duplicate(true),
		"command_steps": state.command_steps,
	})
