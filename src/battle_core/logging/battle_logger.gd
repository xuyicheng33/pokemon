extends RefCounted
class_name BattleLogger

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var event_log: Array = []
var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
    return {
        "code": last_error_code,
        "message": last_error_message,
    }

func reset() -> void:
    event_log.clear()
    last_error_code = null
    last_error_message = ""

func append_event(log_event) -> void:
    if log_event == null:
        last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        last_error_message = "BattleLogger received null log_event"
        return
    event_log.append(log_event)

func snapshot() -> Array:
    return event_log.duplicate()
