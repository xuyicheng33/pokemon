extends Control
class_name BattleSandboxController

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const SandboxPolicyDriverScript := preload("res://src/adapters/sandbox_policy_driver.gd")
const SandboxPlayerUIBuilderScript := preload("res://src/adapters/sandbox_player_ui_builder.gd")
const SandboxSessionCoordinatorScript := preload("res://src/adapters/sandbox_session_coordinator.gd")
const SandboxSessionStateScript := preload("res://src/adapters/sandbox_session_state.gd")
const SandboxViewPresenterScript := preload("res://src/adapters/sandbox_view_presenter.gd")
const SandboxViewRefsScript := preload("res://src/adapters/sandbox_view_refs.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _policy_driver = SandboxPolicyDriverScript.new()
var _player_ui_builder = SandboxPlayerUIBuilderScript.new()
var _session_coordinator = SandboxSessionCoordinatorScript.new()
var _state: SandboxSessionState = SandboxSessionStateScript.new()
var _view_presenter = SandboxViewPresenterScript.new()
var _view_refs: SandboxViewRefs = SandboxViewRefsScript.new()
var _player_ui_mode := "select"

func _ready() -> void:
	_player_ui_builder.build(self)
	_view_refs.bind(self)
	_view_refs.restart_button.pressed.connect(_on_restart_pressed)
	_view_refs.result_restart_button.pressed.connect(_on_result_restart_pressed)
	_view_refs.return_select_button.pressed.connect(_on_return_select_pressed)
	_view_refs.replay_prev_button.pressed.connect(_on_replay_prev_pressed)
	_view_refs.replay_next_button.pressed.connect(_on_replay_next_pressed)
	_view_presenter.configure_static_controls(_view_refs)
	bootstrap_from_environment()

func _exit_tree() -> void:
	var close_result: Dictionary = close_runtime()
	if not bool(close_result.get("ok", true)):
		printerr("BattleSandboxController._exit_tree close_runtime failed: %s" % str(close_result.get("error_message", "unknown error")))

func close_runtime() -> Dictionary:
	return _session_coordinator.close_runtime(_state)

func default_demo_profile_id_result() -> Dictionary:
	if _state.sample_factory == null:
		return ResultEnvelopeHelperScript.error(null, "Battle sandbox sample factory unavailable")
	return _state.sample_factory.default_demo_profile_id_result()

func build_view_model() -> Dictionary:
	_state.sync_event_log_state()
	return _view_presenter.build_view_model(_state.public_snapshot, _build_view_context())

func bootstrap_from_environment() -> Dictionary:
	return bootstrap_with_config(_launch_config_helper.build_config_from_user_args(OS.get_cmdline_user_args()))

func bootstrap_with_config(config: Dictionary) -> Dictionary:
	var bootstrap_result: Dictionary = _session_coordinator.bootstrap_scene(_state, config, _policy_driver)
	_render_ui()
	if bool(bootstrap_result.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(get_state_snapshot())
	return bootstrap_result

func restart_session_with_config(config: Dictionary) -> Dictionary:
	var restart_result: Dictionary = _session_coordinator.bootstrap_scene(_state, config, _policy_driver)
	_render_ui()
	if bool(restart_result.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(get_state_snapshot())
	return restart_result

func start_player_matchup(matchup_id: String) -> Dictionary:
	var next_config := _launch_config_helper.default_config()
	next_config["mode"] = BattleSandboxLaunchConfigScript.MODE_MANUAL_MATCHUP
	next_config["matchup_id"] = matchup_id
	next_config["battle_seed"] = BattleSandboxLaunchConfigScript.DEFAULT_BATTLE_SEED
	next_config["p1_control_mode"] = BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL
	next_config["p2_control_mode"] = BattleSandboxLaunchConfigScript.CONTROL_MODE_POLICY
	_player_ui_mode = "battle"
	return restart_session_with_config(next_config)

func show_matchup_selection() -> void:
	_player_ui_mode = "select"
	_render_ui()

func player_ui_mode() -> String:
	return _player_ui_mode

func current_replay_frame() -> Dictionary:
	return _state.current_replay_frame()

func set_replay_frame(next_index: int) -> void:
	_state.set_replay_frame(next_index)

func get_state_snapshot() -> Dictionary:
	_state.sync_event_log_state()
	return {
		"session_id": _state.session_id,
		"public_snapshot": _state.public_snapshot.duplicate(true),
		"event_log_cursor": _state.event_log_cursor,
		"current_side_to_select": _state.current_side_to_select,
		"pending_commands": _state.pending_commands.duplicate(true),
		"legal_actions_by_side": _state.legal_actions_by_side.duplicate(true),
		"recent_event_lines": _state.recent_event_lines.duplicate(),
		"last_event_delta": _state.last_event_delta.duplicate(true),
		"error_message": _state.error_message,
		"view_model": _state.view_model.duplicate(true),
		"is_demo_mode": _state.is_demo_mode,
		"demo_profile": _state.demo_profile,
		"launch_config": _state.launch_config.duplicate(true),
		"side_control_modes": _state.side_control_modes.duplicate(true),
		"available_matchups": _state.available_matchups.duplicate(true),
		"battle_summary": _state.battle_summary.duplicate(true),
		"command_steps": _state.command_steps,
		"replay_frame_index": _state.replay_frame_index,
		"replay_turn_timeline": _state.replay_turn_timeline.duplicate(true),
		"replay_current_frame": current_replay_frame(),
	}

func fetch_legal_actions_for_side(side_id: String) -> Dictionary:
	var legal_actions_unwrap: Dictionary = _session_coordinator.fetch_legal_actions_for_side(_state, side_id)
	_render_ui()
	if not bool(legal_actions_unwrap.get("ok", false)):
		return legal_actions_unwrap
	var normalized_side_id = str(side_id).strip_edges()
	return ResultEnvelopeHelperScript.ok({
		"legal_actions": legal_actions_unwrap.get("data", null),
		"summary": _state.view_model.get("legal_actions_by_side", {}).get(normalized_side_id, {}),
	})

func submit_action(selected_action: Dictionary) -> Dictionary:
	var submit_result: Dictionary = _session_coordinator.submit_action(_state, selected_action, _policy_driver)
	if bool(submit_result.get("ok", false)) and _view_presenter.battle_finished(_state.public_snapshot):
		_player_ui_mode = "result"
	_render_ui()
	if bool(submit_result.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(submit_result.get("data", null))
	return submit_result

func _render_ui() -> void:
	_state.sync_event_log_state()
	_state.view_model = build_view_model()
	var render_result: Dictionary = _view_presenter.render(self, _state, _view_refs, _state.view_model)
	var manifest_error_message := String(render_result.get("manifest_error_message", "")).strip_edges()
	if not manifest_error_message.is_empty() and _state.error_message.strip_edges().is_empty():
		_state.error_message = manifest_error_message

func _on_restart_pressed() -> void:
	_player_ui_mode = "battle"
	if _state.is_demo_mode:
		restart_session_with_config(_state.launch_config)
		return
	restart_session_with_config(_view_presenter.build_launch_config_from_controls(_state, _view_refs))

func _on_result_restart_pressed() -> void:
	_player_ui_mode = "battle"
	restart_session_with_config(_state.launch_config)

func _on_return_select_pressed() -> void:
	show_matchup_selection()

func _on_replay_prev_pressed() -> void:
	if not _state.is_demo_mode:
		return
	set_replay_frame(_state.replay_frame_index - 1)
	_render_ui()

func _on_replay_next_pressed() -> void:
	if not _state.is_demo_mode:
		return
	set_replay_frame(_state.replay_frame_index + 1)
	_render_ui()

func _build_view_context() -> Dictionary:
	return {
		"current_side_to_select": _state.current_side_to_select,
		"pending_commands": _state.pending_commands,
		"legal_actions_by_side": _state.legal_actions_by_side,
		"recent_event_lines": _state.recent_event_lines,
		"error_message": _state.error_message,
		"launch_config": _state.launch_config,
		"side_control_modes": _state.side_control_modes,
		"available_matchups": _state.available_matchups,
		"battle_summary": _state.battle_summary,
		"command_steps": _state.command_steps,
		"replay_mode": _state.is_demo_mode,
		"replay_frame_index": _state.replay_frame_index,
		"replay_frame_count": _state.replay_turn_timeline.size(),
		"replay_current_frame": current_replay_frame(),
		"player_ui_mode": _player_ui_mode,
	}
