extends RefCounted
class_name PlayerEventLogStreamer

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var _last_cursor: int = 0

func reset() -> void:
	_last_cursor = 0

func pull_increment(manager, session_id: String) -> Dictionary:
	if manager == null:
		return _error(ErrorCodesScript.INVALID_COMPOSITION, "PlayerEventLogStreamer.pull_increment requires manager")
	var normalized_session_id := str(session_id).strip_edges()
	if normalized_session_id.is_empty():
		return _error(ErrorCodesScript.INVALID_SESSION, "PlayerEventLogStreamer.pull_increment requires non-empty session_id")
	var snapshot_result: Dictionary = manager.get_event_log_snapshot(normalized_session_id, _last_cursor)
	if not bool(snapshot_result.get("ok", false)):
		return _error(
			str(snapshot_result.get("error_code", ErrorCodesScript.INVALID_SESSION)),
			str(snapshot_result.get("error_message", "PlayerEventLogStreamer.pull_increment failed"))
		)
	var snapshot_data = snapshot_result.get("data", {})
	if not (snapshot_data is Dictionary):
		return _error(ErrorCodesScript.INVALID_STATE_CORRUPTION, "PlayerEventLogStreamer.pull_increment received non-dict event log snapshot")
	var events_value = snapshot_data.get("events", [])
	var events: Array = []
	if events_value is Array:
		events = events_value.duplicate(true)
	var total_size: int = int(snapshot_data.get("total_size", _last_cursor))
	_last_cursor = total_size
	return {
		"ok": true,
		"events": events,
		"total_size": total_size,
		"error_code": null,
		"error_message": null,
	}

func cursor() -> int:
	return _last_cursor

func _error(error_code: String, error_message: String) -> Dictionary:
	return {
		"ok": false,
		"events": [],
		"total_size": _last_cursor,
		"error_code": error_code,
		"error_message": error_message,
	}
