extends RefCounted
class_name EffectQueueService

func sort_events(effect_events: Array, rng_service) -> Array:
    assert(rng_service != null, "EffectQueueService.rng_service is required")
    var grouped_events: Dictionary = {}
    for effect_event in effect_events:
        var group_key: String = "%d|%d|%d|%s" % [
            effect_event.priority,
            effect_event.source_order_speed_snapshot,
            effect_event.source_kind_order,
            effect_event.source_instance_id,
        ]
        if not grouped_events.has(group_key):
            grouped_events[group_key] = []
        grouped_events[group_key].append(effect_event)
    for group_key in grouped_events.keys():
        var group: Array = grouped_events[group_key]
        if group.size() > 1:
            for effect_event in group:
                effect_event.sort_random_roll = rng_service.next_float()
    var sorted_events: Array = effect_events.duplicate()
    sorted_events.sort_custom(_sort_effect_events)
    return sorted_events

func _sort_effect_events(left, right) -> bool:
    if left.priority != right.priority:
        return left.priority > right.priority
    if left.source_order_speed_snapshot != right.source_order_speed_snapshot:
        return left.source_order_speed_snapshot > right.source_order_speed_snapshot
    if left.source_kind_order != right.source_kind_order:
        return left.source_kind_order < right.source_kind_order
    if left.source_instance_id != right.source_instance_id:
        return left.source_instance_id < right.source_instance_id
    if left.sort_random_roll != null and right.sort_random_roll != null and left.sort_random_roll != right.sort_random_roll:
        return left.sort_random_roll < right.sort_random_roll
    return left.event_id < right.event_id
