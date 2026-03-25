extends RefCounted
class_name BattleLogger

var event_log: Array = []

func append_event(log_event) -> void:
    event_log.append(log_event)
