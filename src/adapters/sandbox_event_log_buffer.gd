extends RefCounted
class_name SandboxEventLogBuffer

const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")

const MAX_EVENT_LINES := 24

var event_log_cursor: int = 0
var recent_event_lines: Array = []
var last_event_delta: Array = []
var battle_summary: Dictionary = {}
var _last_rendered_turn_index: int = 0

func reset() -> void:
	event_log_cursor = 0
	recent_event_lines.clear()
	last_event_delta.clear()
	battle_summary.clear()
	_last_rendered_turn_index = 0

func apply_replay_events(public_snapshot: Dictionary, event_log: Array, summary_context: Dictionary = {}) -> void:
	recent_event_lines.clear()
	_last_rendered_turn_index = 0
	last_event_delta = event_log.duplicate(true)
	_append_event_lines(event_log)
	event_log_cursor = event_log.size()
	_update_battle_summary(public_snapshot, summary_context)

func apply_replay_frame(
	public_snapshot: Dictionary,
	frame: Dictionary,
	event_log: Array,
	summary_context: Dictionary = {}
) -> void:
	recent_event_lines.clear()
	_last_rendered_turn_index = 0
	var event_from := clampi(int(frame.get("event_from", 0)), 0, event_log.size())
	var event_to := clampi(int(frame.get("event_to", 0)), event_from, event_log.size())
	last_event_delta = event_log.slice(event_from, event_to).duplicate(true)
	if last_event_delta.is_empty():
		recent_event_lines.append("• 当前 frame 无事件")
	else:
		_append_event_lines(last_event_delta)
	event_log_cursor = event_to
	_update_battle_summary(public_snapshot, summary_context)

func apply_event_log_snapshot(
	public_snapshot: Dictionary,
	from_index: int,
	event_log_snapshot: Dictionary,
	summary_context: Dictionary = {}
) -> void:
	last_event_delta = event_log_snapshot.get("events", []).duplicate(true)
	_append_event_lines(last_event_delta)
	event_log_cursor = int(event_log_snapshot.get("total_size", from_index))
	_update_battle_summary(public_snapshot, summary_context)

func _append_event_lines(event_snapshots: Array) -> void:
	for event_snapshot in event_snapshots:
		var turn_index := int(_read_property(event_snapshot, "turn_index", 0))
		if turn_index > 0 and turn_index != _last_rendered_turn_index:
			recent_event_lines.append("== Turn %d ==" % turn_index)
			_last_rendered_turn_index = turn_index
		recent_event_lines.append(_format_event_line(event_snapshot))
	while recent_event_lines.size() > MAX_EVENT_LINES:
		recent_event_lines.pop_front()

func _format_event_line(event_snapshot) -> String:
	if event_snapshot is Dictionary or typeof(event_snapshot) == TYPE_OBJECT:
		var event_type := str(_read_property(event_snapshot, "event_type", "")).strip_edges()
		var actor_public_id := str(_read_property(event_snapshot, "actor_public_id", "")).strip_edges()
		var target_public_id := str(_read_property(event_snapshot, "target_public_id", "")).strip_edges()
		var skill_id := str(_read_property(event_snapshot, "skill_id", "")).strip_edges()
		var command_type := str(_read_property(event_snapshot, "command_type", "")).strip_edges()
		var payload_summary := str(_read_property(event_snapshot, "payload_summary", "")).strip_edges()
		if not payload_summary.is_empty():
			return "• %s" % payload_summary
		var parts: Array = []
		if not event_type.is_empty():
			parts.append(event_type)
		if not command_type.is_empty():
			parts.append("cmd=%s" % command_type)
		if not actor_public_id.is_empty():
			parts.append("actor=%s" % actor_public_id)
		if not target_public_id.is_empty():
			parts.append("target=%s" % target_public_id)
		if not skill_id.is_empty():
			parts.append("skill=%s" % skill_id)
		if not parts.is_empty():
			return "• %s" % " | ".join(parts)
		return "• %s" % JSON.stringify(event_snapshot)
	return "• %s" % str(event_snapshot)

func _update_battle_summary(public_snapshot: Dictionary, summary_context: Dictionary = {}) -> void:
	var battle_result = public_snapshot.get("battle_result", null)
	battle_summary = {
		"matchup_id": str(summary_context.get("matchup_id", "")).strip_edges(),
		"battle_seed": int(summary_context.get("battle_seed", 0)),
		"p1_control_mode": str(summary_context.get("p1_control_mode", "")).strip_edges(),
		"p2_control_mode": str(summary_context.get("p2_control_mode", "")).strip_edges(),
		"winner_side_id": "",
		"reason": "",
		"result_type": "",
		"turn_index": int(summary_context.get("turn_index_override", public_snapshot.get("turn_index", 0))),
		"event_log_cursor": event_log_cursor,
		"command_steps": int(summary_context.get("command_steps", 0)),
	}
	if battle_result is Dictionary:
		battle_summary["winner_side_id"] = str(battle_result.get("winner_side_id", "")).strip_edges()
		battle_summary["reason"] = str(battle_result.get("reason", "")).strip_edges()
		battle_summary["result_type"] = str(battle_result.get("result_type", "")).strip_edges()

func _read_property(value, property_name: String, default_value = null):
	return PropertyAccessHelperScript.read_property(value, property_name, default_value)
