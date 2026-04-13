extends RefCounted
class_name SandboxEventLogBuffer

const MAX_EVENT_LINES := 24

var event_log_cursor: int = 0
var recent_event_lines: Array = []
var last_event_delta: Array = []
var battle_summary: Dictionary = {}

func reset() -> void:
	event_log_cursor = 0
	recent_event_lines.clear()
	last_event_delta.clear()
	battle_summary.clear()

func apply_replay_events(public_snapshot: Dictionary, event_log: Array) -> void:
	recent_event_lines.clear()
	last_event_delta = event_log.duplicate(true)
	_append_event_lines(event_log)
	event_log_cursor = event_log.size()
	_update_battle_summary(public_snapshot)

func apply_event_log_snapshot(public_snapshot: Dictionary, from_index: int, event_log_snapshot: Dictionary) -> void:
	last_event_delta = event_log_snapshot.get("events", []).duplicate(true)
	_append_event_lines(last_event_delta)
	event_log_cursor = int(event_log_snapshot.get("total_size", from_index))
	_update_battle_summary(public_snapshot)

func _append_event_lines(event_snapshots: Array) -> void:
	for event_snapshot in event_snapshots:
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

func _update_battle_summary(public_snapshot: Dictionary) -> void:
	battle_summary.clear()
	var battle_result = public_snapshot.get("battle_result", null)
	if not (battle_result is Dictionary) or not bool(battle_result.get("finished", false)):
		return
	battle_summary = {
		"winner_side_id": str(battle_result.get("winner_side_id", "")).strip_edges(),
		"reason": str(battle_result.get("reason", "")).strip_edges(),
		"result_type": str(battle_result.get("result_type", "")).strip_edges(),
		"turn_index": int(public_snapshot.get("turn_index", 0)),
		"event_log_cursor": event_log_cursor,
	}

func _read_property(value, property_name: String, default_value = null):
	if value == null or property_name.is_empty():
		return default_value
	if value is Dictionary:
		return value.get(property_name, default_value)
	if typeof(value) != TYPE_OBJECT:
		return default_value
	for property_info in value.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return value.get(property_name)
	return default_value
