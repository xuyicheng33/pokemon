extends RefCounted
class_name SandboxSessionCoordinator

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const EnvelopeHelperScript := preload("res://src/adapters/sandbox_session_coordinator_envelope_helper.gd")
const SIDE_ORDER := ["P1", "P2"]

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _selection_adapter = PlayerSelectionAdapterScript.new()
var _envelope = EnvelopeHelperScript.new()

func bootstrap_scene(controller, requested_config: Dictionary, policy_driver) -> Dictionary:
	controller._startup_failed = false
	controller.error_message = ""
	close_session_if_needed(controller)
	dispose_manager(controller)
	reset_state(controller)
	var compose_error = _compose_dependencies(controller)
	if not compose_error.is_empty():
		fail_runtime(controller, compose_error)
		return _error_result(compose_error)
	var available_matchups_error = _load_available_matchups(controller)
	if not available_matchups_error.is_empty():
		fail_runtime(controller, available_matchups_error)
		return _error_result(available_matchups_error)
	controller.launch_config = _launch_config_helper.normalize_config(requested_config, controller.available_matchups)
	controller.side_control_modes = _launch_config_helper.side_control_modes(controller.launch_config)
	controller.is_demo_mode = str(controller.launch_config.get("mode", "")) == BattleSandboxLaunchConfigScript.MODE_DEMO_REPLAY
	controller.demo_profile = str(controller.launch_config.get("demo_profile_id", "")).strip_edges()
	if controller.is_demo_mode:
		var replay_error = _run_demo_replay(controller, controller.demo_profile)
		if not replay_error.is_empty():
			fail_runtime(controller, replay_error)
			return _error_result(replay_error)
		return {"ok": true}
	var manual_error = _create_session_for_launch_config(controller)
	if not manual_error.is_empty():
		fail_runtime(controller, manual_error)
		return _error_result(manual_error)
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

func submit_action(
	controller,
	selected_action: Dictionary,
	policy_driver,
	command_source: String = "manual",
	allow_policy_progression: bool = true
) -> Dictionary:
	return _submit_action_core(controller, selected_action, policy_driver, command_source, allow_policy_progression)

func refresh_legal_actions_for_side(controller, side_id: String) -> Dictionary:
	if side_id.is_empty():
		return {"ok": true, "data": null}
	var legal_actions_unwrap := _envelope.unwrap_ok(
		controller.manager.get_legal_actions(controller.session_id, side_id),
		"get_legal_actions(%s)" % side_id
	)
	if not bool(legal_actions_unwrap.get("ok", false)):
		return legal_actions_unwrap
	controller.legal_actions_by_side[side_id] = legal_actions_unwrap.get("data", null)
	return legal_actions_unwrap

func has_battle_result(controller) -> bool:
	var battle_result = controller.public_snapshot.get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func fail_runtime(controller, message: String) -> void:
	if message.is_empty():
		return
	controller.error_message = message
	controller._startup_failed = true
	printerr("BATTLE_SANDBOX_FAILED: %s" % message)

func reset_state(controller) -> void:
	controller.session_id = ""
	controller.battle_setup = null
	controller.public_snapshot = {}
	controller.legal_actions_by_side.clear()
	controller.pending_commands.clear()
	controller.current_side_to_select = ""
	controller.error_message = ""
	controller.view_model = {}
	controller.launch_config = _launch_config_helper.default_config()
	controller.side_control_modes = _launch_config_helper.side_control_modes(controller.launch_config)
	controller.available_matchups.clear()
	controller.demo_profile = ""
	controller.is_demo_mode = false
	controller.command_steps = 0
	controller._event_log_buffer.reset()

func close_session_if_needed(controller) -> void:
	if controller.manager == null or str(controller.session_id).strip_edges().is_empty():
		return
	controller.manager.close_session(controller.session_id)
	controller.session_id = ""

func dispose_manager(controller) -> void:
	if controller.manager != null and controller.manager.has_method("dispose"):
		controller.manager.dispose()
	controller.manager = null
	controller.composer = null
	controller.sample_factory = null

func _compose_dependencies(controller) -> String:
	controller.composer = BattleCoreComposerScript.new()
	if controller.composer == null:
		return "Battle sandbox failed to construct composer"
	controller.manager = controller.composer.compose_manager()
	if controller.manager == null:
		var composer_error: Dictionary = controller.composer.error_state()
		return "Battle sandbox failed to compose manager: %s" % str(composer_error.get("message", "unknown composition error"))
	controller.sample_factory = SampleBattleFactoryScript.new()
	if controller.sample_factory == null:
		return "Battle sandbox failed to construct sample battle factory"
	return ""

func _load_available_matchups(controller) -> String:
	var available_result: Dictionary = controller.sample_factory.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		return "Battle sandbox failed to load available matchups: %s" % str(available_result.get("error_message", "unknown error"))
	var descriptors = available_result.get("data", [])
	if not (descriptors is Array):
		return "Battle sandbox available matchups result must be array"
	controller.available_matchups = descriptors.duplicate(true)
	return ""

func _run_demo_replay(controller, profile_id: String) -> String:
	var profile_result: Dictionary = controller.sample_factory.demo_profile_result(profile_id)
	if not bool(profile_result.get("ok", false)):
		return "Battle sandbox failed to resolve demo profile %s: %s" % [
			profile_id,
			str(profile_result.get("error_message", "unknown error")),
		]
	var profile: Dictionary = profile_result.get("data", {})
	var replay_result: Dictionary = controller.sample_factory.build_demo_replay_input_for_profile_result(controller.manager, profile_id)
	var replay_unwrap_result: Dictionary = _envelope.unwrap_sample_factory_result(replay_result, "%s demo replay input" % profile_id)
	if not bool(replay_unwrap_result.get("ok", false)):
		return str(replay_unwrap_result.get("error", "Battle sandbox replay input failed"))
	var replay_input = replay_unwrap_result.get("data", null)
	var replay_unwrap: Dictionary = _envelope.unwrap_ok(controller.manager.run_replay(replay_input), "run_replay(%s)" % profile_id)
	if not bool(replay_unwrap.get("ok", false)):
		return str(replay_unwrap.get("error", "Battle sandbox replay failed"))
	var replay_payload: Dictionary = replay_unwrap.get("data", {})
	controller.public_snapshot = replay_payload.get("public_snapshot", {})
	var replay_output = replay_payload.get("replay_output", null)
	var event_log: Array = []
	if replay_output != null:
		event_log = replay_output.event_log
	controller._event_log_buffer.apply_replay_events(
		controller.public_snapshot,
		event_log,
		_envelope.build_summary_context({
			"matchup_id": str(profile.get("matchup_id", BattleSandboxLaunchConfigScript.DEFAULT_MATCHUP_ID)).strip_edges(),
			"battle_seed": int(profile.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)),
		}, controller.side_control_modes, controller.command_steps)
	)
	controller.current_side_to_select = ""
	controller.pending_commands.clear()
	controller.legal_actions_by_side.clear()
	return ""

func _create_session_for_launch_config(controller) -> String:
	var matchup_id = str(controller.launch_config.get("matchup_id", BattleSandboxLaunchConfigScript.DEFAULT_MATCHUP_ID)).strip_edges()
	var setup_result: Dictionary = controller.sample_factory.build_setup_by_matchup_id_result(matchup_id)
	if not bool(setup_result.get("ok", false)):
		return "Battle sandbox failed to build matchup %s: %s" % [
			matchup_id,
			str(setup_result.get("error_message", "unknown error")),
		]
	controller.battle_setup = setup_result.get("data", {})
	if controller.battle_setup == null:
		return "Battle sandbox received empty battle_setup for %s" % matchup_id
	var snapshot_paths_result: Dictionary = controller.sample_factory.content_snapshot_paths_for_setup_result(controller.battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return "Battle sandbox failed to resolve setup snapshot paths: %s" % str(snapshot_paths_result.get("error_message", "unknown error"))
	var create_unwrap: Dictionary = _envelope.unwrap_ok(
		controller.manager.create_session({
			"battle_seed": int(controller.launch_config.get("battle_seed", BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED)),
			"content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
			"battle_setup": controller.battle_setup,
		}),
		"create_session(%s)" % matchup_id
	)
	if not bool(create_unwrap.get("ok", false)):
		return str(create_unwrap.get("error", "Battle sandbox create_session failed"))
	controller.session_id = str(create_unwrap.get("data", {}).get("session_id", "")).strip_edges()
	if controller.session_id.is_empty():
		return "Battle sandbox create_session returned empty session_id"
	var refresh_error = _refresh_session_snapshot_and_logs(controller, 0)
	if not refresh_error.is_empty():
		return refresh_error
	controller.current_side_to_select = SIDE_ORDER[0]
	var p1_legal_unwrap: Dictionary = refresh_legal_actions_for_side(controller, controller.current_side_to_select)
	if not bool(p1_legal_unwrap.get("ok", false)):
		return str(p1_legal_unwrap.get("error", "Battle sandbox failed to get initial legal actions"))
	return ""

func _refresh_session_snapshot_and_logs(controller, from_index: int) -> String:
	var snapshot_unwrap: Dictionary = _envelope.unwrap_ok(
		controller.manager.get_public_snapshot(controller.session_id),
		"get_public_snapshot(%s)" % controller.session_id
	)
	if not bool(snapshot_unwrap.get("ok", false)):
		return str(snapshot_unwrap.get("error", "Battle sandbox failed to refresh public_snapshot"))
	controller.public_snapshot = snapshot_unwrap.get("data", {})
	var event_log_unwrap: Dictionary = _envelope.unwrap_ok(
		controller.manager.get_event_log_snapshot(controller.session_id, from_index),
		"get_event_log_snapshot(%s)" % controller.session_id
	)
	if not bool(event_log_unwrap.get("ok", false)):
		return str(event_log_unwrap.get("error", "Battle sandbox failed to refresh event log"))
	controller._event_log_buffer.apply_event_log_snapshot(
		controller.public_snapshot,
		from_index,
		event_log_unwrap.get("data", {}),
		_envelope.build_summary_context(controller.launch_config, controller.side_control_modes, controller.command_steps)
	)
	return ""

func _submit_action_core(
	controller,
	selected_action: Dictionary,
	policy_driver,
	command_source: String,
	allow_policy_progression: bool
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
	var actor_public_id = str(_envelope.read_property(legal_actions, "actor_public_id", "")).strip_edges()
	if actor_public_id.is_empty():
		return _error_result("missing actor_public_id for side %s" % side_id)
	var action_payload: Dictionary = selected_action.duplicate(true)
	action_payload["side_id"] = side_id
	action_payload["actor_public_id"] = actor_public_id
	action_payload["turn_index"] = int(controller.public_snapshot.get("turn_index", 1))
	action_payload["command_source"] = command_source
	var command_payload: Dictionary = _selection_adapter.build_player_payload(action_payload)
	var command_unwrap: Dictionary = _envelope.unwrap_ok(
		controller.manager.build_command(command_payload),
		"build_command(%s)" % side_id
	)
	if not bool(command_unwrap.get("ok", false)):
		fail_runtime(controller, str(command_unwrap.get("error", "Battle sandbox failed to build command")))
		return command_unwrap
	controller.command_steps += 1
	controller.pending_commands[side_id] = command_unwrap.get("data", null)
	if side_id == SIDE_ORDER[0]:
		controller.current_side_to_select = SIDE_ORDER[1]
		var refresh_unwrap: Dictionary = refresh_legal_actions_for_side(controller, controller.current_side_to_select)
		if not bool(refresh_unwrap.get("ok", false)):
			fail_runtime(controller, str(refresh_unwrap.get("error", "Battle sandbox failed to refresh legal actions")))
			return refresh_unwrap
		if allow_policy_progression and policy_driver != null:
			var policy_progress_result: Dictionary = policy_driver.advance_until_manual_or_finished(controller, self)
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

func _run_pending_turn(controller, policy_driver, allow_policy_progression: bool) -> Dictionary:
	var commands: Array = []
	for side_id in SIDE_ORDER:
		if not controller.pending_commands.has(side_id):
			return _error_result("missing pending command for side %s" % side_id)
		commands.append(controller.pending_commands.get(side_id, null))
	var from_index: int = controller._event_log_buffer.event_log_cursor
	var run_turn_unwrap: Dictionary = _envelope.unwrap_ok(
		controller.manager.run_turn(controller.session_id, commands),
		"run_turn(%s)" % controller.session_id
	)
	if not bool(run_turn_unwrap.get("ok", false)):
		fail_runtime(controller, str(run_turn_unwrap.get("error", "Battle sandbox run_turn failed")))
		return run_turn_unwrap
	controller.pending_commands.clear()
	controller.legal_actions_by_side.clear()
	controller.current_side_to_select = ""
	var refresh_error = _refresh_session_snapshot_and_logs(controller, from_index)
	if not refresh_error.is_empty():
		fail_runtime(controller, refresh_error)
		return _error_result(refresh_error)
	if not has_battle_result(controller):
		controller.current_side_to_select = SIDE_ORDER[0]
		var legal_unwrap: Dictionary = refresh_legal_actions_for_side(controller, controller.current_side_to_select)
		if not bool(legal_unwrap.get("ok", false)):
			fail_runtime(controller, str(legal_unwrap.get("error", "Battle sandbox failed to refresh next turn legal actions")))
			return legal_unwrap
		if allow_policy_progression and policy_driver != null:
			var policy_progress_result: Dictionary = policy_driver.advance_until_manual_or_finished(controller, self)
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
	return _envelope.error_result(message)
