extends Control
class_name BattleSandboxController

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const SandboxEventLogBufferScript := preload("res://src/adapters/sandbox_event_log_buffer.gd")
const SandboxPolicyDriverScript := preload("res://src/adapters/sandbox_policy_driver.gd")
const SandboxSessionCoordinatorScript := preload("res://src/adapters/sandbox_session_coordinator.gd")
const SandboxViewPresenterScript := preload("res://src/adapters/sandbox_view_presenter.gd")

@warning_ignore("unused_private_class_variable")
@onready var _status_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/StatusLabel
@warning_ignore("unused_private_class_variable")
@onready var _error_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/ErrorLabel
@warning_ignore("unused_private_class_variable")
@onready var _battle_summary_label: Label = $RootMargin/MainColumn/HeaderPanel/HeaderContent/BattleSummaryLabel
@warning_ignore("unused_private_class_variable")
@onready var _p1_summary: RichTextLabel = $RootMargin/MainColumn/BodyRow/P1Panel/P1Content/P1Summary
@warning_ignore("unused_private_class_variable")
@onready var _event_header_label: Label = $RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventHeaderLabel
@warning_ignore("unused_private_class_variable")
@onready var _event_log_text: RichTextLabel = $RootMargin/MainColumn/BodyRow/EventPanel/EventContent/EventLogText
@warning_ignore("unused_private_class_variable")
@onready var _p2_summary: RichTextLabel = $RootMargin/MainColumn/BodyRow/P2Panel/P2Content/P2Summary
@warning_ignore("unused_private_class_variable")
@onready var _config_status_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigStatusLabel
@warning_ignore("unused_private_class_variable")
@onready var _matchup_select: OptionButton = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/MatchupSelect
@warning_ignore("unused_private_class_variable")
@onready var _battle_seed_input: LineEdit = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/BattleSeedInput
@warning_ignore("unused_private_class_variable")
@onready var _p1_mode_select: OptionButton = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/P1ModeSelect
@warning_ignore("unused_private_class_variable")
@onready var _p2_mode_select: OptionButton = $RootMargin/MainColumn/ActionPanel/ActionContent/ConfigPanel/ConfigContent/ConfigGrid/P2ModeSelect
@warning_ignore("unused_private_class_variable")
@onready var _action_header_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/ActionHeaderLabel
@warning_ignore("unused_private_class_variable")
@onready var _pending_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/PendingLabel
@warning_ignore("unused_private_class_variable")
@onready var _primary_buttons: HBoxContainer = $RootMargin/MainColumn/ActionPanel/ActionContent/PrimaryButtons
@warning_ignore("unused_private_class_variable")
@onready var _switch_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/SwitchLabel
@warning_ignore("unused_private_class_variable")
@onready var _switch_buttons: HBoxContainer = $RootMargin/MainColumn/ActionPanel/ActionContent/SwitchButtons
@warning_ignore("unused_private_class_variable")
@onready var _utility_buttons: HBoxContainer = $RootMargin/MainColumn/ActionPanel/ActionContent/UtilityButtons
@warning_ignore("unused_private_class_variable")
@onready var _restart_button: Button = $RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/RestartButton
@warning_ignore("unused_private_class_variable")
@onready var _replay_controls: HBoxContainer = $RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls
@warning_ignore("unused_private_class_variable")
@onready var _replay_prev_button: Button = $RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls/ReplayPrevButton
@warning_ignore("unused_private_class_variable")
@onready var _replay_turn_label: Label = $RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls/ReplayTurnLabel
@warning_ignore("unused_private_class_variable")
@onready var _replay_next_button: Button = $RootMargin/MainColumn/ActionPanel/ActionContent/ControlButtons/ReplayControls/ReplayNextButton

var composer = null
var manager = null
var sample_factory = null

var session_id: String = ""
var battle_setup = null
var public_snapshot: Dictionary = {}
var event_log_cursor: int = 0
var legal_actions_by_side: Dictionary = {}
var pending_commands: Dictionary = {}
var current_side_to_select: String = ""
var recent_event_lines: Array = []
var last_event_delta: Array = []
var error_message: String = ""
var view_model: Dictionary = {}
var launch_config: Dictionary = {}
var side_control_modes: Dictionary = {}
var available_matchups: Array = []
var battle_summary: Dictionary = {}
var command_steps: int = 0
var replay_event_log: Array = []
var replay_turn_timeline: Array = []
var replay_summary_context: Dictionary = {}
var replay_frame_index: int = 0

var demo_profile: String = ""
var is_demo_mode: bool = false

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _event_log_buffer = SandboxEventLogBufferScript.new()
var _policy_driver = SandboxPolicyDriverScript.new()
var _session_coordinator = SandboxSessionCoordinatorScript.new()
var _view_presenter = SandboxViewPresenterScript.new()
@warning_ignore("unused_private_class_variable")
var _startup_failed: bool = false

func _ready() -> void:
	_restart_button.pressed.connect(_on_restart_pressed)
	_replay_prev_button.pressed.connect(_on_replay_prev_pressed)
	_replay_next_button.pressed.connect(_on_replay_next_pressed)
	_view_presenter.configure_static_controls(self)
	bootstrap_from_environment()

func _exit_tree() -> void:
	_session_coordinator.close_session_if_needed(self)
	_session_coordinator.dispose_manager(self)

func build_view_model() -> Dictionary:
	_sync_event_log_state()
	return _view_presenter.build_view_model(public_snapshot, _build_view_context())

func bootstrap_from_environment() -> Dictionary:
	return bootstrap_with_config(_launch_config_helper.build_config_from_user_args(OS.get_cmdline_user_args()))

func bootstrap_with_config(config: Dictionary) -> Dictionary:
	var bootstrap_result: Dictionary = _session_coordinator.bootstrap_scene(self, config, _policy_driver)
	_render_ui()
	if bool(bootstrap_result.get("ok", false)):
		return {"ok": true, "data": get_state_snapshot()}
	return bootstrap_result

func restart_session_with_config(config: Dictionary) -> Dictionary:
	var restart_result: Dictionary = _session_coordinator.bootstrap_scene(self, config, _policy_driver)
	_render_ui()
	if bool(restart_result.get("ok", false)):
		return {"ok": true, "data": get_state_snapshot()}
	return restart_result

func configure_replay_browser(replay_output, summary_context: Dictionary) -> String:
	if replay_output == null:
		return "Battle sandbox replay returned null replay_output"
	if not (replay_output.turn_timeline is Array) or replay_output.turn_timeline.is_empty():
		return "Battle sandbox replay missing turn_timeline"
	replay_summary_context = summary_context.duplicate(true)
	replay_event_log = replay_output.event_log.duplicate(true)
	replay_turn_timeline = replay_output.turn_timeline.duplicate(true)
	replay_frame_index = 0
	_apply_replay_frame()
	return ""

func current_replay_frame() -> Dictionary:
	if replay_turn_timeline.is_empty():
		return {}
	var clamped_index := clampi(replay_frame_index, 0, replay_turn_timeline.size() - 1)
	var frame = replay_turn_timeline[clamped_index]
	return frame.duplicate(true) if frame is Dictionary else {}

func set_replay_frame(next_index: int) -> void:
	if replay_turn_timeline.is_empty():
		return
	replay_frame_index = clampi(next_index, 0, replay_turn_timeline.size() - 1)
	_apply_replay_frame()

func get_state_snapshot() -> Dictionary:
	_sync_event_log_state()
	return {
		"session_id": session_id,
		"battle_setup": battle_setup,
		"public_snapshot": public_snapshot.duplicate(true),
		"event_log_cursor": event_log_cursor,
		"current_side_to_select": current_side_to_select,
		"pending_commands": pending_commands.duplicate(),
		"legal_actions_by_side": legal_actions_by_side.duplicate(),
		"recent_event_lines": recent_event_lines.duplicate(),
		"last_event_delta": last_event_delta.duplicate(true),
		"error_message": error_message,
		"view_model": view_model.duplicate(true),
		"is_demo_mode": is_demo_mode,
		"demo_profile": demo_profile,
		"launch_config": launch_config.duplicate(true),
		"side_control_modes": side_control_modes.duplicate(true),
		"available_matchups": available_matchups.duplicate(true),
		"battle_summary": battle_summary.duplicate(true),
		"command_steps": command_steps,
		"replay_frame_index": replay_frame_index,
		"replay_turn_timeline": replay_turn_timeline.duplicate(true),
		"replay_current_frame": current_replay_frame(),
	}

func fetch_legal_actions_for_side(side_id: String) -> Dictionary:
	var legal_actions_unwrap: Dictionary = _session_coordinator.fetch_legal_actions_for_side(self, side_id)
	_render_ui()
	if not bool(legal_actions_unwrap.get("ok", false)):
		return legal_actions_unwrap
	var normalized_side_id = str(side_id).strip_edges()
	return {
		"ok": true,
		"data": legal_actions_unwrap.get("data", null),
		"summary": view_model.get("legal_actions_by_side", {}).get(normalized_side_id, {}),
	}

func submit_action(selected_action: Dictionary) -> Dictionary:
	var submit_result: Dictionary = _session_coordinator.submit_action(self, selected_action, _policy_driver)
	_render_ui()
	return submit_result

func _render_ui() -> void:
	_sync_event_log_state()
	view_model = build_view_model()
	_view_presenter.render(self, view_model)

func _on_restart_pressed() -> void:
	if is_demo_mode:
		restart_session_with_config(launch_config)
		return
	restart_session_with_config(_view_presenter.build_launch_config_from_controls(self))

func _on_replay_prev_pressed() -> void:
	if not is_demo_mode:
		return
	set_replay_frame(replay_frame_index - 1)
	_render_ui()

func _on_replay_next_pressed() -> void:
	if not is_demo_mode:
		return
	set_replay_frame(replay_frame_index + 1)
	_render_ui()

func _apply_replay_frame() -> void:
	if replay_turn_timeline.is_empty():
		return
	var frame := current_replay_frame()
	public_snapshot = frame.get("public_snapshot", {}).duplicate(true)
	_event_log_buffer.apply_replay_frame(
		public_snapshot,
		frame,
		replay_event_log,
		_build_replay_summary_context(frame)
	)
	current_side_to_select = ""
	pending_commands.clear()
	legal_actions_by_side.clear()

func _build_replay_summary_context(frame: Dictionary) -> Dictionary:
	var summary_context: Dictionary = replay_summary_context.duplicate(true)
	summary_context["turn_index_override"] = int(frame.get("turn_index", 0))
	return summary_context

func _sync_event_log_state() -> void:
	event_log_cursor = _event_log_buffer.event_log_cursor
	recent_event_lines = _event_log_buffer.recent_event_lines.duplicate()
	last_event_delta = _event_log_buffer.last_event_delta.duplicate(true)
	battle_summary = _event_log_buffer.battle_summary.duplicate(true)

func _build_view_context() -> Dictionary:
	return {
		"current_side_to_select": current_side_to_select,
		"pending_commands": pending_commands,
		"legal_actions_by_side": legal_actions_by_side,
		"recent_event_lines": recent_event_lines,
		"error_message": error_message,
		"launch_config": launch_config,
		"side_control_modes": side_control_modes,
		"available_matchups": available_matchups,
		"battle_summary": battle_summary,
		"command_steps": command_steps,
		"replay_mode": is_demo_mode,
		"replay_frame_index": replay_frame_index,
		"replay_frame_count": replay_turn_timeline.size(),
		"replay_current_frame": current_replay_frame(),
	}
