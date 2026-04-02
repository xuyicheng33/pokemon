extends RefCounted
class_name FieldService

const SOURCE_KIND_ORDER_FIELD := 1
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var trigger_dispatcher
var trigger_batch_runner
var last_invalid_battle_code: Variant = null

func resolve_missing_dependency() -> String:
    if trigger_dispatcher == null:
        return "trigger_dispatcher"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    return ""

func collect_trigger_events(trigger_name: String, battle_state, content_index, chain_context) -> Array:
    last_invalid_battle_code = null
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
    var effect_events = trigger_dispatcher.collect_events(
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
    last_invalid_battle_code = trigger_dispatcher.last_invalid_battle_code
    return effect_events

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
    last_invalid_battle_code = null
    if field_state == null or content_index == null or effect_ids.is_empty():
        return []
    var lifecycle_chain_context = _build_lifecycle_chain_context(chain_context, battle_state, field_state.creator)
    var effect_events = trigger_dispatcher.collect_events(
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
    last_invalid_battle_code = trigger_dispatcher.last_invalid_battle_code
    return effect_events

func break_field_if_creator_inactive(battle_state, content_index, chain_context) -> Variant:
    if battle_state.field_state == null:
        return null
    var creator_id := String(battle_state.field_state.creator)
    if creator_id.is_empty():
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    var creator_unit = battle_state.get_unit(creator_id)
    if creator_unit != null and creator_unit.current_hp > 0 and creator_unit.leave_state == LeaveStatesScript.ACTIVE:
        return null
    return break_active_field(battle_state, content_index, "field_break", chain_context)

func break_active_field(battle_state, content_index, trigger_name: String, chain_context) -> Variant:
    if battle_state.field_state == null:
        return null
    if trigger_batch_runner == null:
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
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
                chain_context,
                break_events
            )
            if break_invalid_code != null:
                return break_invalid_code
    _clear_old_field_if_still_active(battle_state, current_field_state)
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

func clear_field_state_if_matches(battle_state, field_state) -> void:
    if battle_state == null or field_state == null:
        return
    _clear_old_field_if_still_active(battle_state, field_state)

func _clear_old_field_if_still_active(battle_state, field_state) -> void:
    if battle_state == null or field_state == null:
        return
    _remove_field_rule_mods_for_instance(battle_state, String(field_state.instance_id))
    var active_field = battle_state.field_state
    if active_field == null:
        return
    if String(active_field.instance_id) != String(field_state.instance_id):
        return
    battle_state.field_state = null

func _remove_field_rule_mods_for_instance(battle_state, field_instance_id: String) -> void:
    if battle_state == null:
        return
    if field_instance_id.is_empty():
        battle_state.field_rule_mod_instances.clear()
        return
    var keep_instances: Array = []
    for rule_mod_instance in battle_state.field_rule_mod_instances:
        var owner_field_instance_id := String(rule_mod_instance.field_instance_id) if rule_mod_instance != null else ""
        var source_instance_id := String(rule_mod_instance.source_instance_id) if rule_mod_instance != null else ""
        if owner_field_instance_id == field_instance_id or source_instance_id == field_instance_id:
            continue
        keep_instances.append(rule_mod_instance)
    battle_state.field_rule_mod_instances = keep_instances
