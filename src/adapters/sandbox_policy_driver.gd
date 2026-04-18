extends RefCounted
class_name SandboxPolicyDriver

const BattleSandboxFirstLegalPolicyScript := preload("res://src/adapters/battle_sandbox_first_legal_policy.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const MAX_POLICY_COMMAND_STEPS := 256

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _policy_port = BattleSandboxFirstLegalPolicyScript.new()

func advance_until_manual_or_finished(state: SandboxSessionState, session_coordinator) -> Dictionary:
	var command_steps = 0
	while not state.startup_failed and not state.is_demo_mode and not session_coordinator.has_battle_result(state):
		var side_id = str(state.current_side_to_select).strip_edges()
		if side_id.is_empty() or not _is_policy_side(state.side_control_modes, side_id):
			return ResultEnvelopeHelperScript.ok({"command_steps": command_steps})
		if command_steps >= MAX_POLICY_COMMAND_STEPS:
			var limit_error = "Battle sandbox policy exceeded command step limit %d" % MAX_POLICY_COMMAND_STEPS
			session_coordinator.fail_runtime(state, limit_error)
			return _error_result(limit_error)
		var legal_actions = state.legal_actions_by_side.get(side_id, null)
		if legal_actions == null:
			var refresh_unwrap: Dictionary = session_coordinator.refresh_legal_actions_for_side(state, side_id)
			if not bool(refresh_unwrap.get("ok", false)):
				session_coordinator.fail_runtime(state, str(refresh_unwrap.get("error_message", "Battle sandbox failed to refresh policy legal actions")))
				return refresh_unwrap
			legal_actions = refresh_unwrap.get("data", null)
		var action_result: Dictionary = _policy_port.select_action_result(
			legal_actions,
			state.public_snapshot.duplicate(true),
			_build_policy_context(state)
		)
		if not bool(action_result.get("ok", false)):
			var policy_error = str(action_result.get("error_message", "Battle sandbox policy failed to select action"))
			session_coordinator.fail_runtime(state, policy_error)
			return _error_result(policy_error)
		var submit_result: Dictionary = session_coordinator.submit_action(state, action_result.get("data", {}), null, "manual", false)
		if not bool(submit_result.get("ok", false)):
			return submit_result
		command_steps += 1
	return ResultEnvelopeHelperScript.ok({"command_steps": command_steps})

func _is_policy_side(side_control_modes: Dictionary, side_id: String) -> bool:
	return _launch_config_helper.is_policy_control_mode(
		str(side_control_modes.get(side_id, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges()
	)

func _build_policy_context(state: SandboxSessionState) -> Dictionary:
	return {
		"launch_config": state.launch_config.duplicate(true),
		"side_control_modes": state.side_control_modes.duplicate(true),
		"current_side_to_select": state.current_side_to_select,
		"event_log_cursor": int(state.event_log_buffer.event_log_cursor),
		"battle_summary": state.event_log_buffer.battle_summary.duplicate(true),
	}

func _error_result(message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(null, message)
