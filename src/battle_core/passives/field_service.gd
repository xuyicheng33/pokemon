extends RefCounted
class_name FieldService

const SOURCE_KIND_ORDER_FIELD := 1
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var trigger_dispatcher
var trigger_batch_runner

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

func get_field_definition_for_state(field_state, content_index):
    if field_state == null or content_index == null:
        return null
    return content_index.fields.get(field_state.field_def_id)

func collect_lifecycle_effect_events(
    trigger_name: String,
    field_state,
    effect_ids: PackedStringArray,
    battle_state,
    content_index,
    chain_context
) -> Array:
    if field_state == null or content_index == null or effect_ids.is_empty():
        return []
    var lifecycle_chain_context = _build_lifecycle_chain_context(chain_context, battle_state, field_state.creator)
    return trigger_dispatcher.collect_events(
        trigger_name,
        battle_state,
        content_index,
        effect_ids,
        field_state.creator,
        field_state.instance_id,
        SOURCE_KIND_ORDER_FIELD,
        field_state.source_order_speed_snapshot,
        lifecycle_chain_context
    )

func break_field_if_creator_inactive(battle_state, content_index, chain_context) -> Variant:
    if battle_state.field_state == null:
        return null
    var creator_id := String(battle_state.field_state.creator)
    if creator_id.is_empty():
        return null
    var creator_unit = battle_state.get_unit(creator_id)
    if creator_unit != null and creator_unit.current_hp > 0 and creator_unit.leave_state == LeaveStatesScript.ACTIVE:
        return null
    return break_active_field(battle_state, content_index, "field_break", chain_context)

func break_active_field(battle_state, content_index, trigger_name: String, chain_context) -> Variant:
    if battle_state.field_state == null:
        return null
    assert(trigger_batch_runner != null, "FieldService.trigger_batch_runner is required")
    var current_field_state = battle_state.field_state
    var field_definition = get_field_definition_for_state(current_field_state, content_index)
    if field_definition != null and not field_definition.on_break_effect_ids.is_empty():
        var break_events: Array = collect_lifecycle_effect_events(
            trigger_name,
            current_field_state,
            field_definition.on_break_effect_ids,
            battle_state,
            content_index,
            chain_context
        )
        if not break_events.is_empty():
            var break_invalid_code = trigger_batch_runner.execute_trigger_batch(
                "__field_break__",
                battle_state,
                content_index,
                [],
                battle_state.chain_context,
                break_events
            )
            if break_invalid_code != null:
                return break_invalid_code
    battle_state.field_rule_mod_instances.clear()
    battle_state.field_state = null
    return null

func tick_turn_end(field_state) -> bool:
    if field_state == null:
        return false
    field_state.remaining_turns -= 1
    return field_state.remaining_turns <= 0

func build_matchup_signature(battle_state) -> String:
    var active_ids: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        if active_unit == null or active_unit.current_hp <= 0:
            return ""
        active_ids.append(active_unit.unit_instance_id)
    active_ids.sort()
    return "|".join(PackedStringArray(active_ids))

func resolve_opponent_active_id_for_creator(battle_state, creator_id: String) -> Variant:
    if creator_id.is_empty():
        return null
    var side_state = battle_state.get_side_for_unit(creator_id)
    if side_state == null:
        return null
    var opponent_side = battle_state.get_opponent_side(side_state.side_id)
    if opponent_side == null:
        return null
    var target_unit = opponent_side.get_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY)
    if target_unit == null or target_unit.current_hp <= 0:
        return null
    return target_unit.unit_instance_id

func _build_lifecycle_chain_context(chain_context, battle_state, creator_id: String):
    if chain_context == null:
        return null
    var lifecycle_chain_context = chain_context.copy_shallow()
    lifecycle_chain_context.actor_id = creator_id
    lifecycle_chain_context.target_slot = ContentSchemaScript.ACTIVE_SLOT_PRIMARY
    lifecycle_chain_context.target_unit_id = resolve_opponent_active_id_for_creator(battle_state, creator_id)
    return lifecycle_chain_context
