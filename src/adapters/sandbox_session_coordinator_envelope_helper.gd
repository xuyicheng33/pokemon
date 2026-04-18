extends RefCounted
class_name SandboxSessionCoordinatorEnvelopeHelper

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

func build_summary_context(launch_config: Dictionary, side_control_modes: Dictionary, command_steps: int) -> Dictionary:
	return {
		"matchup_id": str(launch_config.get("matchup_id", BattleSandboxLaunchConfigScript.DEFAULT_MATCHUP_ID)).strip_edges(),
		"battle_seed": int(launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)),
		"p1_control_mode": str(side_control_modes.get("P1", BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges(),
		"p2_control_mode": str(side_control_modes.get("P2", BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges(),
		"command_steps": int(command_steps),
	}

func unwrap_sample_factory_result(result: Dictionary, label: String) -> Dictionary:
	return ResultEnvelopeHelperScript.unwrap_ok(
		result,
		"Battle sandbox failed to build %s" % label
	)

func unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	return ResultEnvelopeHelperScript.unwrap_ok(envelope, label)

func read_property(value, property_name: String, default_value = null):
	return PropertyAccessHelperScript.read_property(value, property_name, default_value)

func error_result(message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(null, message)

func ok_result(data = null) -> Dictionary:
	return ResultEnvelopeHelperScript.ok(data)
