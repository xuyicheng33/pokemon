extends RefCounted
class_name TriggerDispatcher

const EffectEventScript := preload("res://src/battle_core/contracts/effect_event.gd")

var id_factory

func collect_events(trigger_name: String, _battle_state, content_index, effect_ids: PackedStringArray, owner_id: String, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int, chain_context) -> Array:
    var effect_events: Array = []
    for effect_id in effect_ids:
        var effect_definition = content_index.effects.get(effect_id)
        assert(effect_definition != null, "Missing effect definition: %s" % effect_id)
        var effect_event = EffectEventScript.new()
        effect_event.event_id = id_factory.next_id("effect_event")
        effect_event.trigger_name = trigger_name
        effect_event.priority = effect_definition.priority
        effect_event.source_instance_id = source_instance_id
        effect_event.source_kind_order = source_kind_order
        effect_event.source_order_speed_snapshot = source_order_speed_snapshot
        effect_event.effect_definition_id = effect_id
        effect_event.owner_id = owner_id
        effect_event.chain_context = chain_context
        effect_events.append(effect_event)
    return effect_events
