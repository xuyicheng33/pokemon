extends RefCounted
class_name LogCauseTestHelper

func event_id(log_event) -> String:
    return "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]

func find_event(event_log: Array, predicate: Callable):
    for ev in event_log:
        if predicate.call(ev):
            return ev
    return null

func find_events(event_log: Array, predicate: Callable) -> Array:
    var matched: Array = []
    for ev in event_log:
        if predicate.call(ev):
            matched.append(ev)
    return matched

func _event_id(log_event) -> String:
    return event_id(log_event)

func _find_event(event_log: Array, predicate: Callable):
    return find_event(event_log, predicate)

func _find_events(event_log: Array, predicate: Callable) -> Array:
    return find_events(event_log, predicate)
