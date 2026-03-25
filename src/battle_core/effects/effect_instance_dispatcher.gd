extends RefCounted
class_name EffectInstanceDispatcher

const EffectEventScript := preload("res://src/battle_core/contracts/effect_event.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var id_factory

func collect_trigger_events(trigger_name: String, battle_state, content_index, owner_unit_ids: Array, chain_context) -> Array:
    var effect_events: Array = []
    for owner_id in owner_unit_ids:
        var owner_unit = battle_state.get_unit(str(owner_id))
        if owner_unit == null:
            continue
        for effect_instance in owner_unit.effect_instances:
            var effect_definition = content_index.effects.get(effect_instance.def_id)
            assert(effect_definition != null, "Missing effect definition: %s" % effect_instance.def_id)
            if not effect_definition.trigger_names.has(trigger_name):
                continue
            var effect_event = EffectEventScript.new()
            effect_event.event_id = id_factory.next_id("effect_event")
            effect_event.trigger_name = trigger_name
            effect_event.priority = effect_definition.priority
            effect_event.source_instance_id = effect_instance.source_instance_id
            effect_event.source_kind_order = effect_instance.source_kind_order
            effect_event.source_order_speed_snapshot = effect_instance.source_order_speed_snapshot
            effect_event.effect_definition_id = effect_definition.id
            effect_event.owner_id = owner_unit.unit_instance_id
            effect_event.chain_context = chain_context
            effect_events.append(effect_event)
    return effect_events

func decrement_for_trigger(trigger_name: String, battle_state, content_index, owner_unit_ids: Array) -> Array:
    var removed_instances: Array = []
    for owner_id in owner_unit_ids:
        var owner_unit = battle_state.get_unit(str(owner_id))
        if owner_unit == null:
            continue
        var keep_instances: Array = []
        for effect_instance in owner_unit.effect_instances:
            var effect_definition = content_index.effects.get(effect_instance.def_id)
            assert(effect_definition != null, "Missing effect definition: %s" % effect_instance.def_id)
            var should_remove: bool = false
            if effect_definition.duration_mode == ContentSchemaScript.DURATION_TURNS and effect_definition.decrement_on == trigger_name:
                effect_instance.remaining -= 1
                if effect_instance.remaining <= 0:
                    should_remove = true
            if should_remove:
                removed_instances.append({
                    "owner_id": owner_unit.unit_instance_id,
                    "instance": effect_instance,
                    "definition": effect_definition,
                })
            else:
                keep_instances.append(effect_instance)
        owner_unit.effect_instances = keep_instances
    return removed_instances
