extends RefCounted
class_name SandboxSessionCommandService

const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const EnvelopeHelperScript := preload("res://src/adapters/sandbox_session_coordinator_envelope_helper.gd")
const SIDE_ORDER := ["P1", "P2"]

var selection_adapter = PlayerSelectionAdapterScript.new()
var envelope = EnvelopeHelperScript.new()

func primary_side_id() -> String:
	return SIDE_ORDER[0]

func advance_until_manual_or_finished(controller, policy_driver) -> Dictionary:
	if policy_driver == null:
		return {"ok": true}
	return policy_driver.advance_until_manual_or_finished(controller, self)

func fetch_legal_actions_for_side(controller, side_id: String) -> Dictionary:
	var normalized_side_id = str(side_id).strip_edges()
	if normalized_side_id.is_empty():
		return _error_result("side_id is required")
	if controller.is_demo_mode:
		return _error_result("demo mode does not expose legal actions")
	if controller.manager == null or str(controller.session_id).strip_edges().is_empty():
		return _error_result("manual scene has no active session")
	return refresh_legal_actions_for_side(controller, normalized_side_id)

func refresh_legal_actions_for_side(controller, side_id: String) -> Dictionary:
	if side_id.is_empty():
		return {"ok": true, "data": null}
	var legal_actions_unwrap := envelope.unwrap_ok(
		controller.manager.get_legal_actions(controller.session_id, side_id),
		"get_legal_actions(%s)" % side_id
	)
	if not bool(legal_actions_unwrap.get("ok", false)):
		return legal_actions_unwrap
	controller.legal_actions_by_side[side_id] = legal_actions_unwrap.get("data", null)
	return legal_actions_unwrap

func submit_action(
	controller,
	selected_action: Dictionary,
	policy_driver,
	command_source: String = "manual",
	allow_policy_progression: bool = true
) -> Dictionary:
	if controller.is_demo_mode:
		return _error_result("demo mode does not accept manual actions")
	if controller._startup_failed:
		return _error_result("battle sandbox is in failed state")
	if has_battle_result(controller):
		return _error_result("battle already finished")
	var side_id = str(controller.current_side_to_select).strip_edges()
	if side_id.is_empty():
		return _error_result("no side is waiting for selection")
	var legal_actions = controller.legal_actions_by_side.get(side_id, null)
	var actor_public_id = str(envelope.read_property(legal_actions, "actor_public_id", "")).strip_edges()
	if actor_public_id.is_empty():
		return _error_result("missing actor_public_id for side %s" % side_id)
	var action_payload: Dictionary = selected_action.duplicate(true)
	action_payload["side_id"] = side_id
	action_payload["actor_public_id"] = actor_public_id
	action_payload["turn_index"] = int(controller.public_snapshot.get("turn_index", 1))
	action_payload["command_source"] = command_source
	var command_payload: Dictionary = selection_adapter.build_player_payload(action_payload)
	var command_unwrap: Dictionary = envelope.unwrap_ok(
		controller.manager.build_command(command_payload),
		"build_command(%s)" % side_id
	)
	if not bool(command_unwrap.get("ok", false)):
		fail_runtime(controller, str(command_unwrap.get("error", "Battle sandbox failed to build command")))
		return command_unwrap
	controller.command_steps += 1
	controller.pending_commands[side_id] = command_unwrap.get("data", null)
	if side_id == primary_side_id():
		controller.current_side_to_select = SIDE_ORDER[1]
		var refresh_unwrap: Dictionary = refresh_legal_actions_for_side(controller, controller.current_side_to_select)
		if not bool(refresh_unwrap.get("ok", false)):
			fail_runtime(controller, str(refresh_unwrap.get("error", "Battle sandbox failed to refresh legal actions")))
			return refresh_unwrap
		if allow_policy_progression:
			var policy_progress_result: Dictionary = advance_until_manual_or_finished(controller, policy_driver)
			if not bool(policy_progress_result.get("ok", false)):
				return policy_progress_result
		return {
			"ok": true,
			"data": {
				"side_id": side_id,
				"pending_commands": controller.pending_commands.size(),
				"current_side_to_select": controller.current_side_to_select,
				"command_steps": controller.command_steps,
			},
		}
	return _run_pending_turn(controller, policy_driver, allow_policy_progression)

func has_battle_result(controller) -> bool:
	var battle_result = controller.public_snapshot.get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func fail_runtime(controller, message: String) -> void:
	if message.is_empty():
		return
	controller.error_message = message
	controller._startup_failed = true
	printerr("BATTLE_SANDBOX_FAILED: %s" % message)

func refresh_session_snapshot_and_logs(controller, from_index: int) -> String:
	var snapshot_unwrap: Dictionary = envelope.unwrap_ok(
		controller.manager.get_public_snapshot(controller.session_id),
		"get_public_snapshot(%s)" % controller.session_id
	)
	if not bool(snapshot_unwrap.get("ok", false)):
		return str(snapshot_unwrap.get("error", "Battle sandbox failed to refresh public_snapshot"))
	controller.public_snapshot = snapshot_unwrap.get("data", {})
	var event_log_unwrap: Dictionary = envelope.unwrap_ok(
		controller.manager.get_event_log_snapshot(controller.session_id, from_index),
		"get_event_log_snapshot(%s)" % controller.session_id
	)
	if not bool(event_log_unwrap.get("ok", false)):
		return str(event_log_unwrap.get("error", "Battle sandbox failed to refresh event log"))
	controller._event_log_buffer.apply_event_log_snapshot(
		controller.public_snapshot,
		from_index,
		event_log_unwrap.get("data", {}),
		envelope.build_summary_context(controller.launch_config, controller.side_control_modes, controller.command_steps)
	)
	return ""

func _run_pending_turn(controller, policy_driver, allow_policy_progression: bool) -> Dictionary:
	var commands: Array = []
	for side_id in SIDE_ORDER:
		if not controller.pending_commands.has(side_id):
			return _error_result("missing pending command for side %s" % side_id)
		commands.append(controller.pending_commands.get(side_id, null))
	var from_index: int = controller._event_log_buffer.event_log_cursor
	var run_turn_unwrap: Dictionary = envelope.unwrap_ok(
		controller.manager.run_turn(controller.session_id, commands),
		"run_turn(%s)" % controller.session_id
	)
	if not bool(run_turn_unwrap.get("ok", false)):
		fail_runtime(controller, str(run_turn_unwrap.get("error", "Battle sandbox run_turn failed")))
		return run_turn_unwrap
	controller.pending_commands.clear()
	controller.legal_actions_by_side.clear()
	controller.current_side_to_select = ""
	var refresh_error = refresh_session_snapshot_and_logs(controller, from_index)
	if not refresh_error.is_empty():
		fail_runtime(controller, refresh_error)
		return _error_result(refresh_error)
	if not has_battle_result(controller):
		controller.current_side_to_select = primary_side_id()
		var legal_unwrap: Dictionary = refresh_legal_actions_for_side(controller, controller.current_side_to_select)
		if not bool(legal_unwrap.get("ok", false)):
			fail_runtime(controller, str(legal_unwrap.get("error", "Battle sandbox failed to refresh next turn legal actions")))
			return legal_unwrap
		if allow_policy_progression:
			var policy_progress_result: Dictionary = advance_until_manual_or_finished(controller, policy_driver)
			if not bool(policy_progress_result.get("ok", false)):
				return policy_progress_result
	return {
		"ok": true,
		"data": {
			"event_log_cursor": controller._event_log_buffer.event_log_cursor,
			"battle_finished": has_battle_result(controller),
			"event_delta": controller._event_log_buffer.last_event_delta.duplicate(true),
			"public_snapshot": controller.public_snapshot.duplicate(true),
			"current_side_to_select": controller.current_side_to_select,
			"battle_summary": controller._event_log_buffer.battle_summary.duplicate(true),
			"command_steps": controller.command_steps,
		}
	}

func _error_result(message: String) -> Dictionary:
	return envelope.error_result(message)
