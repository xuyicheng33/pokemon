extends RefCounted
class_name SandboxSessionCoordinator

const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const EnvelopeHelperScript := preload("res://src/adapters/sandbox_session_coordinator_envelope_helper.gd")
const SandboxSessionBootstrapServiceScript := preload("res://src/adapters/sandbox_session_bootstrap_service.gd")
const SandboxSessionDemoServiceScript := preload("res://src/adapters/sandbox_session_demo_service.gd")
const SandboxSessionCommandServiceScript := preload("res://src/adapters/sandbox_session_command_service.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _selection_adapter = PlayerSelectionAdapterScript.new()
var _envelope = EnvelopeHelperScript.new()
var _bootstrap_service = SandboxSessionBootstrapServiceScript.new()
var _demo_service = SandboxSessionDemoServiceScript.new()
var _command_service = SandboxSessionCommandServiceScript.new()

func _init() -> void:
	_bootstrap_service.launch_config_helper = _launch_config_helper
	_bootstrap_service.command_service = _command_service
	_demo_service.envelope = _envelope
	_command_service.selection_adapter = _selection_adapter
	_command_service.envelope = _envelope

func bootstrap_scene(controller, requested_config: Dictionary, policy_driver) -> Dictionary:
	controller._startup_failed = false
	controller.error_message = ""
	close_session_if_needed(controller)
	dispose_manager(controller)
	reset_state(controller)
	var bootstrap_error = _bootstrap_service.prepare_scene(controller, requested_config)
	if not bootstrap_error.is_empty():
		fail_runtime(controller, bootstrap_error)
		return _error_result(bootstrap_error)
	if controller.is_demo_mode:
		var replay_error = _demo_service.run_demo_replay(controller, controller.demo_profile)
		if not replay_error.is_empty():
			fail_runtime(controller, replay_error)
			return _error_result(replay_error)
		return {"ok": true}
	if policy_driver == null:
		return {"ok": true}
	var policy_result: Dictionary = _command_service.advance_until_manual_or_finished(controller, policy_driver)
	if not bool(policy_result.get("ok", false)):
		return policy_result
	return {"ok": true}

func fetch_legal_actions_for_side(controller, side_id: String) -> Dictionary:
	return _command_service.fetch_legal_actions_for_side(controller, side_id)

func submit_action(
	controller,
	selected_action: Dictionary,
	policy_driver,
	command_source: String = "manual",
	allow_policy_progression: bool = true
) -> Dictionary:
	return _command_service.submit_action(
		controller,
		selected_action,
		policy_driver,
		command_source,
		allow_policy_progression
	)

func refresh_legal_actions_for_side(controller, side_id: String) -> Dictionary:
	return _command_service.refresh_legal_actions_for_side(controller, side_id)

func has_battle_result(controller) -> bool:
	return _command_service.has_battle_result(controller)

func fail_runtime(controller, message: String) -> void:
	_command_service.fail_runtime(controller, message)

func reset_state(controller) -> void:
	_bootstrap_service.reset_state(controller)

func close_session_if_needed(controller) -> void:
	_bootstrap_service.close_session_if_needed(controller)

func dispose_manager(controller) -> void:
	_bootstrap_service.dispose_manager(controller)

func _error_result(message: String) -> Dictionary:
	return _envelope.error_result(message)
