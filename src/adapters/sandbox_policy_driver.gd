extends RefCounted
class_name SandboxPolicyDriver

const BattleSandboxFirstLegalPolicyScript := preload("res://src/adapters/battle_sandbox_first_legal_policy.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const MAX_POLICY_COMMAND_STEPS := 256

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _policy_port = BattleSandboxFirstLegalPolicyScript.new()

func advance_until_manual_or_finished(controller, session_coordinator) -> Dictionary:
	var command_steps = 0
	while not controller._startup_failed and not controller.is_demo_mode and not session_coordinator.has_battle_result(controller):
		var side_id = str(controller.current_side_to_select).strip_edges()
		if side_id.is_empty() or not _is_policy_side(controller.side_control_modes, side_id):
			return {"ok": true, "data": {"command_steps": command_steps}}
		if command_steps >= MAX_POLICY_COMMAND_STEPS:
			var limit_error = "Battle sandbox policy exceeded command step limit %d" % MAX_POLICY_COMMAND_STEPS
			session_coordinator.fail_runtime(controller, limit_error)
			return _error_result(limit_error)
		var legal_actions = controller.legal_actions_by_side.get(side_id, null)
		if legal_actions == null:
			var refresh_unwrap: Dictionary = session_coordinator.refresh_legal_actions_for_side(controller, side_id)
			if not bool(refresh_unwrap.get("ok", false)):
				session_coordinator.fail_runtime(controller, str(refresh_unwrap.get("error", "Battle sandbox failed to refresh policy legal actions")))
				return refresh_unwrap
			legal_actions = refresh_unwrap.get("data", null)
		var action_result: Dictionary = _policy_port.select_action_result(
			legal_actions,
			controller.public_snapshot.duplicate(true),
			_build_policy_context(controller)
		)
		if not bool(action_result.get("ok", false)):
			var policy_error = str(action_result.get("error", "Battle sandbox policy failed to select action"))
			session_coordinator.fail_runtime(controller, policy_error)
			return _error_result(policy_error)
		var submit_result: Dictionary = session_coordinator.submit_action(controller, action_result.get("data", {}), null, "manual", false)
		if not bool(submit_result.get("ok", false)):
			return submit_result
		command_steps += 1
	return {"ok": true, "data": {"command_steps": command_steps}}

func _is_policy_side(side_control_modes: Dictionary, side_id: String) -> bool:
	return _launch_config_helper.is_policy_control_mode(
		str(side_control_modes.get(side_id, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges()
	)

func _build_policy_context(controller) -> Dictionary:
	return {
		"launch_config": controller.launch_config.duplicate(true),
		"side_control_modes": controller.side_control_modes.duplicate(true),
		"current_side_to_select": controller.current_side_to_select,
		"event_log_cursor": int(controller._event_log_buffer.event_log_cursor),
		"battle_summary": controller._event_log_buffer.battle_summary.duplicate(true),
	}

func _error_result(message: String) -> Dictionary:
	return {"ok": false, "error": message}
