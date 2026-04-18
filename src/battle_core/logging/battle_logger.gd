extends RefCounted
class_name BattleLogger

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

var event_log: Array = []
var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func reset() -> void:
	event_log.clear()
	ErrorStateHelperScript.clear(self)

func append_event(log_event) -> void:
	if log_event == null:
		ErrorStateHelperScript.fail(self, ErrorCodesScript.INVALID_STATE_CORRUPTION, "BattleLogger received null log_event")
		return
	event_log.append(log_event)

func snapshot() -> Array:
	return event_log.duplicate()
