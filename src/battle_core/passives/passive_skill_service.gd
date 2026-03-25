extends RefCounted
class_name PassiveSkillService

const SOURCE_KIND_ORDER_PASSIVE_SKILL := 3

var trigger_dispatcher

func collect_trigger_events(trigger_name: String, battle_state, content_index, owner_unit_ids: Array, chain_context) -> Array:
    var effect_events: Array = []
    for owner_id in owner_unit_ids:
        var owner_unit = battle_state.get_unit(owner_id)
        if owner_unit == null:
            continue
        var unit_definition = content_index.units.get(owner_unit.definition_id)
        if unit_definition == null or unit_definition.passive_skill_id.is_empty():
            continue
        var passive_definition = content_index.passive_skills.get(unit_definition.passive_skill_id)
        if passive_definition == null:
            continue
        if not passive_definition.trigger_names.has(trigger_name):
            continue
        if passive_definition.effect_ids.is_empty():
            continue
        var source_speed_snapshot: int = owner_unit.last_effective_speed if owner_unit.last_effective_speed > 0 else owner_unit.base_speed
        var source_instance_id: String = "passive_skill:%s:%s" % [owner_unit.unit_instance_id, passive_definition.id]
        var triggered_events: Array = trigger_dispatcher.collect_events(
            trigger_name,
            battle_state,
            content_index,
            passive_definition.effect_ids,
            owner_unit.unit_instance_id,
            source_instance_id,
            SOURCE_KIND_ORDER_PASSIVE_SKILL,
            source_speed_snapshot,
            chain_context
        )
        effect_events.append_array(triggered_events)
    return effect_events
