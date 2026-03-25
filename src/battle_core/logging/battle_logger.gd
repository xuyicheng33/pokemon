extends RefCounted
class_name BattleLogger

var event_log: Array = []

func reset() -> void:
    event_log.clear()

func append_event(log_event) -> void:
    event_log.append(log_event)

func snapshot() -> Array:
    return event_log.duplicate()
