extends RefCounted
class_name FieldService

const SOURCE_KIND_ORDER_FIELD := 1

var trigger_dispatcher

func collect_trigger_events(trigger_name: String, battle_state, content_index, chain_context) -> Array:
    if battle_state.field_state == null:
        return []
    var field_definition = content_index.fields.get(battle_state.field_state.field_def_id)
    if field_definition == null:
        return []
    var effect_ids: PackedStringArray = PackedStringArray()
    for effect_id in field_definition.effect_ids:
        var effect_definition = content_index.effects.get(effect_id)
        if effect_definition == null:
            continue
        if not effect_definition.trigger_names.has(trigger_name):
            continue
        effect_ids.append(effect_id)
    if effect_ids.is_empty():
        return []
    return trigger_dispatcher.collect_events(
        trigger_name,
        battle_state,
        content_index,
        effect_ids,
        battle_state.field_state.creator,
        battle_state.field_state.instance_id,
        SOURCE_KIND_ORDER_FIELD,
        battle_state.field_state.source_order_speed_snapshot,
        chain_context
    )

func tick_turn_end(field_state) -> bool:
    if field_state == null:
        return false
    field_state.remaining_turns -= 1
    return field_state.remaining_turns <= 0
