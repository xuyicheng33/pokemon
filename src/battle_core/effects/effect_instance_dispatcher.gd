extends RefCounted
class_name EffectInstanceDispatcher

const EffectEventScript := preload("res://src/battle_core/contracts/effect_event.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var id_factory
var last_invalid_battle_code: Variant = null

func collect_trigger_events(trigger_name: String, battle_state, content_index, owner_unit_ids: Array, chain_context) -> Array:
    last_invalid_battle_code = null
    var effect_events: Array = []
    for owner_id in owner_unit_ids:
        var owner_unit = battle_state.get_unit(str(owner_id))
        if owner_unit == null:
            continue
        for effect_instance in owner_unit.effect_instances:
            var effect_definition = content_index.effects.get(effect_instance.def_id)
            if effect_definition == null:
                last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
                return []
            if not effect_definition.trigger_names.has(trigger_name):
                continue
            var effect_event = EffectEventScript.new()
            effect_event.event_id = id_factory.next_id("effect_event")
            effect_event.trigger_name = trigger_name
            effect_event.priority = effect_definition.priority
            effect_event.source_instance_id = effect_instance.source_instance_id
            effect_event.effect_instance_id = effect_instance.instance_id
            effect_event.source_kind_order = effect_instance.source_kind_order
            effect_event.source_order_speed_snapshot = effect_instance.source_order_speed_snapshot
            effect_event.effect_definition_id = effect_definition.id
            effect_event.owner_id = owner_unit.unit_instance_id
            effect_event.chain_context = chain_context
            effect_events.append(effect_event)
    return effect_events

func decrement_for_trigger(trigger_name: String, battle_state, content_index, owner_unit_ids: Array) -> Dictionary:
    last_invalid_battle_code = null
    var removed_instances: Array = []
    var expire_events: Array = []
    for owner_id in owner_unit_ids:
        var owner_unit = battle_state.get_unit(str(owner_id))
        if owner_unit == null:
            continue
        var keep_instances: Array = []
        for effect_instance in owner_unit.effect_instances:
            var effect_definition = content_index.effects.get(effect_instance.def_id)
            if effect_definition == null:
                last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
                return {
                    "removed_instances": [],
                    "expire_events": [],
                    "invalid_code": last_invalid_battle_code,
                }
            var should_remove: bool = false
            if effect_definition.duration_mode == ContentSchemaScript.DURATION_TURNS and effect_definition.decrement_on == trigger_name:
                effect_instance.remaining -= 1
                if effect_instance.remaining <= 0:
                    should_remove = true
            if should_remove:
                if not effect_definition.on_expire_effect_ids.is_empty():
                    expire_events.append_array(_collect_expire_events(
                        effect_instance,
                        effect_definition,
                        owner_unit.unit_instance_id,
                        battle_state,
                        content_index
                    ))
                    if last_invalid_battle_code != null:
                        return {
                            "removed_instances": [],
                            "expire_events": [],
                            "invalid_code": last_invalid_battle_code,
                        }
                removed_instances.append({
                    "owner_id": owner_unit.unit_instance_id,
                    "instance": effect_instance,
                    "definition": effect_definition,
                })
            else:
                keep_instances.append(effect_instance)
        owner_unit.effect_instances = keep_instances
    return {
        "removed_instances": removed_instances,
        "expire_events": expire_events,
        "invalid_code": null,
    }

func _collect_expire_events(effect_instance, effect_definition, owner_id: String, battle_state, content_index) -> Array:
    var expire_events: Array = []
    for effect_id in effect_definition.on_expire_effect_ids:
        var next_effect_definition = content_index.effects.get(effect_id)
        if next_effect_definition == null:
            last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
            return []
        var effect_event = EffectEventScript.new()
        effect_event.event_id = id_factory.next_id("effect_event")
        effect_event.trigger_name = "on_expire"
        effect_event.priority = next_effect_definition.priority
        effect_event.source_instance_id = effect_instance.instance_id
        effect_event.effect_instance_id = effect_instance.instance_id
        effect_event.source_kind_order = effect_instance.source_kind_order
        effect_event.source_order_speed_snapshot = effect_instance.source_order_speed_snapshot
        effect_event.effect_definition_id = effect_id
        effect_event.owner_id = owner_id
        effect_event.chain_context = _build_expire_chain_context(battle_state.chain_context, battle_state, owner_id)
        expire_events.append(effect_event)
    return expire_events

func _build_expire_chain_context(chain_context, battle_state, owner_id: String):
    if chain_context == null:
        return null
    var expire_chain_context = chain_context.copy_shallow()
    expire_chain_context.actor_id = owner_id
    var owner_side = battle_state.get_side_for_unit(owner_id)
    if owner_side == null:
        expire_chain_context.target_unit_id = null
        return expire_chain_context
    var opponent_side = battle_state.get_opponent_side(owner_side.side_id)
    var opponent_active = opponent_side.get_active_unit() if opponent_side != null else null
    expire_chain_context.target_unit_id = opponent_active.unit_instance_id if opponent_active != null and opponent_active.current_hp > 0 else null
    return expire_chain_context
