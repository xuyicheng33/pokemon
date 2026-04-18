extends RefCounted
class_name SandboxSessionDemoService

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const EnvelopeHelperScript := preload("res://src/adapters/sandbox_session_coordinator_envelope_helper.gd")

var envelope = EnvelopeHelperScript.new()

func run_demo_replay(controller, profile_id: String) -> String:
	var profile_result: Dictionary = controller.sample_factory.demo_profile_result(profile_id)
	if not bool(profile_result.get("ok", false)):
		return "Battle sandbox failed to resolve demo profile %s: %s" % [
			profile_id,
			str(profile_result.get("error_message", "unknown error")),
		]
	var profile: Dictionary = profile_result.get("data", {})
	var replay_result: Dictionary = controller.sample_factory.build_demo_replay_input_for_profile_result(controller.manager, profile_id)
	var replay_unwrap_result: Dictionary = envelope.unwrap_sample_factory_result(replay_result, "%s demo replay input" % profile_id)
	if not bool(replay_unwrap_result.get("ok", false)):
		return str(replay_unwrap_result.get("error", "Battle sandbox replay input failed"))
	var replay_input = replay_unwrap_result.get("data", null)
	var replay_unwrap: Dictionary = envelope.unwrap_ok(controller.manager.run_replay(replay_input), "run_replay(%s)" % profile_id)
	if not bool(replay_unwrap.get("ok", false)):
		return str(replay_unwrap.get("error", "Battle sandbox replay failed"))
	var replay_payload: Dictionary = replay_unwrap.get("data", {})
	var replay_output = replay_payload.get("replay_output", null)
	var summary_context := envelope.build_summary_context({
		"matchup_id": str(profile.get("matchup_id", BattleSandboxLaunchConfigScript.DEFAULT_MATCHUP_ID)).strip_edges(),
		"battle_seed": int(profile.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)),
	}, controller.side_control_modes, controller.command_steps)
	var replay_browser_error: String = controller.configure_replay_browser(replay_output, summary_context)
	if not replay_browser_error.is_empty():
		return replay_browser_error
	controller.current_side_to_select = ""
	controller.pending_commands.clear()
	controller.legal_actions_by_side.clear()
	return ""
