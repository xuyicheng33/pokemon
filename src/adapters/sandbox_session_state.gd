extends RefCounted
class_name SandboxSessionState

const SandboxEventLogBufferScript := preload("res://src/adapters/sandbox_event_log_buffer.gd")

var composer: RefCounted = null
var manager: RefCounted = null
var sample_factory: RefCounted = null

var session_id: String = ""
var battle_setup: Variant = null
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
var startup_failed: bool = false

var event_log_buffer: SandboxEventLogBuffer = SandboxEventLogBufferScript.new()

func reset(default_launch_config: Dictionary, default_side_control_modes: Dictionary) -> void:
	session_id = ""
	battle_setup = null
	public_snapshot.clear()
	event_log_cursor = 0
	legal_actions_by_side.clear()
	pending_commands.clear()
	current_side_to_select = ""
	recent_event_lines.clear()
	last_event_delta.clear()
	error_message = ""
	view_model.clear()
	launch_config = default_launch_config.duplicate(true)
	side_control_modes = default_side_control_modes.duplicate(true)
	available_matchups.clear()
	battle_summary.clear()
	command_steps = 0
	replay_event_log.clear()
	replay_turn_timeline.clear()
	replay_summary_context.clear()
	replay_frame_index = 0
	demo_profile = ""
	is_demo_mode = false
	startup_failed = false
	event_log_buffer.reset()

func current_replay_frame() -> Dictionary:
	if replay_turn_timeline.is_empty():
		return {}
	var clamped_index := clampi(replay_frame_index, 0, replay_turn_timeline.size() - 1)
	var frame = replay_turn_timeline[clamped_index]
	return frame.duplicate(true) if frame is Dictionary else {}

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

func set_replay_frame(next_index: int) -> void:
	if replay_turn_timeline.is_empty():
		return
	replay_frame_index = clampi(next_index, 0, replay_turn_timeline.size() - 1)
	_apply_replay_frame()

func sync_event_log_state() -> void:
	event_log_cursor = event_log_buffer.event_log_cursor
	recent_event_lines = event_log_buffer.recent_event_lines.duplicate()
	last_event_delta = event_log_buffer.last_event_delta.duplicate(true)
	battle_summary = event_log_buffer.battle_summary.duplicate(true)

func _apply_replay_frame() -> void:
	if replay_turn_timeline.is_empty():
		return
	var frame := current_replay_frame()
	public_snapshot = frame.get("public_snapshot", {}).duplicate(true)
	event_log_buffer.apply_replay_frame(
		public_snapshot,
		frame,
		replay_event_log,
		_build_replay_summary_context(frame)
	)
	current_side_to_select = ""
	pending_commands.clear()
	legal_actions_by_side.clear()
	sync_event_log_state()

func _build_replay_summary_context(frame: Dictionary) -> Dictionary:
	var summary_context: Dictionary = replay_summary_context.duplicate(true)
	summary_context["turn_index_override"] = int(frame.get("turn_index", 0))
	return summary_context
