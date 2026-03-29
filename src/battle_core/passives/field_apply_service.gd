extends RefCounted
class_name FieldApplyService

const EventTypesScript := preload("res://src/shared/event_types.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const FieldChangeScript := preload("res://src/battle_core/contracts/field_change.gd")

var field_service
var trigger_dispatcher
var trigger_batch_runner
var id_factory
var battle_logger
var log_event_builder
var rng_service

func resolve_missing_dependency() -> String:
    if field_service == null:
        return "field_service"
    if field_service.has_method("resolve_missing_dependency"):
        var field_missing := str(field_service.resolve_missing_dependency())
        if not field_missing.is_empty():
            return "field_service.%s" % field_missing
    if trigger_dispatcher == null:
        return "trigger_dispatcher"
    if trigger_batch_runner == null:
        return "trigger_batch_runner"
    if id_factory == null:
        return "id_factory"
    if battle_logger == null:
        return "battle_logger"
    if log_event_builder == null:
        return "log_event_builder"
    if rng_service == null:
        return "rng_service"
    return ""

func apply_field(effect_definition, payload, effect_event, battle_state, content_index) -> Variant:
    assert(effect_definition != null, "FieldApplyService.apply_field requires effect_definition")
    assert(payload != null, "FieldApplyService.apply_field requires payload")
    assert(effect_event != null, "FieldApplyService.apply_field requires effect_event")
    var before_field = battle_state.field_state
    if before_field != null:
        var clash_result := _resolve_field_clash(before_field, effect_event, battle_state)
        _log_field_clash(clash_result, before_field, payload, effect_event, battle_state)
        if not bool(clash_result.get("challenger_won", false)):
            return null
        var break_invalid_code = field_service.break_active_field(
            battle_state,
            content_index,
            "field_break",
            effect_event.chain_context
        )
        if break_invalid_code != null:
            return break_invalid_code
    var field_state = FieldStateScript.new()
    field_state.field_def_id = payload.field_definition_id
    field_state.instance_id = id_factory.next_id("field")
    field_state.creator = _resolve_field_creator(effect_event)
    field_state.remaining_turns = effect_definition.duration
    field_state.source_instance_id = effect_event.source_instance_id
    field_state.source_kind_order = effect_event.source_kind_order
    field_state.source_order_speed_snapshot = effect_event.source_order_speed_snapshot
    battle_state.field_state = field_state
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_APPLY_FIELD,
        battle_state,
        {
            "source_instance_id": effect_event.source_instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "cause_event_id": effect_event.event_id,
            "effect_roll": effect_event.sort_random_roll,
            "field_change": _build_apply_field_change(before_field, field_state),
            "payload_summary": "field -> %s" % field_state.field_def_id,
        }
    ))
    var field_definition = field_service.get_field_definition_for_state(field_state, content_index)
    if field_definition != null and not field_definition.effect_ids.is_empty():
        var field_apply_invalid_code = _execute_field_effects(
            "field_apply",
            field_state,
            field_definition.effect_ids,
            battle_state,
            content_index,
            effect_event.chain_context
        )
        if field_apply_invalid_code != null:
            return field_apply_invalid_code
    if not payload.on_success_effect_ids.is_empty():
        var follow_up_invalid_code = _execute_success_effects(
            payload.on_success_effect_ids,
            effect_event,
            battle_state,
            content_index
        )
        if follow_up_invalid_code != null:
            return follow_up_invalid_code
    return null

func _execute_field_effects(
    trigger_name: String,
    field_state,
    effect_ids: PackedStringArray,
    battle_state,
    content_index,
    chain_context
) -> Variant:
    var effect_events: Array = field_service.collect_lifecycle_effect_events(
        trigger_name,
        field_state,
        effect_ids,
        battle_state,
        content_index,
        chain_context
    )
    if effect_events.is_empty():
        return null
    return trigger_batch_runner.execute_trigger_batch(
        "__field_%s__" % trigger_name,
        battle_state,
        content_index,
        [],
        battle_state.chain_context,
        effect_events
    )

func _execute_success_effects(effect_ids: PackedStringArray, effect_event, battle_state, content_index) -> Variant:
    var success_events = trigger_dispatcher.collect_events(
        effect_event.trigger_name,
        battle_state,
        content_index,
        effect_ids,
        _resolve_field_creator(effect_event),
        effect_event.source_instance_id,
        effect_event.source_kind_order,
        effect_event.source_order_speed_snapshot,
        effect_event.chain_context
    )
    if success_events.is_empty():
        return null
    return trigger_batch_runner.execute_trigger_batch(
        "__field_apply_success__",
        battle_state,
        content_index,
        [],
        battle_state.chain_context,
        success_events
    )

func _resolve_field_clash(before_field, effect_event, battle_state) -> Dictionary:
    var challenger_creator := _resolve_field_creator(effect_event)
    var incumbent_creator := String(before_field.creator)
    var challenger_mp := _resolve_creator_mp(battle_state, challenger_creator)
    var incumbent_mp := _resolve_creator_mp(battle_state, incumbent_creator)
    if incumbent_creator == challenger_creator:
        return _build_clash_result(true, true, challenger_creator, incumbent_creator, challenger_mp, incumbent_mp, null)
    if challenger_mp > incumbent_mp:
        return _build_clash_result(true, false, challenger_creator, incumbent_creator, challenger_mp, incumbent_mp, null)
    if challenger_mp < incumbent_mp:
        return _build_clash_result(false, false, challenger_creator, incumbent_creator, challenger_mp, incumbent_mp, null)
    var tie_roll: Variant = rng_service.next_float()
    battle_state.rng_stream_index = rng_service.get_stream_index()
    return _build_clash_result(
        tie_roll >= 0.5,
        false,
        challenger_creator,
        incumbent_creator,
        challenger_mp,
        incumbent_mp,
        tie_roll
    )

func _build_clash_result(challenger_won: bool, same_creator: bool, challenger_creator: String, incumbent_creator: String, challenger_mp: int, incumbent_mp: int, tie_roll) -> Dictionary:
    return {
        "challenger_won": challenger_won,
        "same_creator": same_creator,
        "challenger_creator": challenger_creator,
        "incumbent_creator": incumbent_creator,
        "challenger_mp": challenger_mp,
        "incumbent_mp": incumbent_mp,
        "tie_roll": tie_roll,
    }

func _log_field_clash(clash_result: Dictionary, before_field, payload, effect_event, battle_state) -> void:
    if clash_result.is_empty() or bool(clash_result.get("same_creator", false)):
        return
    var challenger_creator := str(clash_result.get("challenger_creator", ""))
    var incumbent_creator := str(clash_result.get("incumbent_creator", ""))
    var challenger_won: bool = bool(clash_result.get("challenger_won", false))
    var winner_creator := challenger_creator if challenger_won else incumbent_creator
    var winner_public_id = _resolve_public_id_or_system(battle_state, winner_creator)
    var payload_summary := "field clash %s(%d) vs %s(%d) -> %s keeps field %s" % [
        payload.field_definition_id,
        int(clash_result.get("challenger_mp", -1)),
        before_field.field_def_id,
        int(clash_result.get("incumbent_mp", -1)),
        winner_public_id,
        payload.field_definition_id if challenger_won else before_field.field_def_id,
    ]
    battle_logger.append_event(log_event_builder.build_effect_event(
        EventTypesScript.EFFECT_FIELD_CLASH,
        battle_state,
        effect_event.event_id,
        {
            "source_instance_id": effect_event.source_instance_id,
            "target_instance_id": before_field.instance_id,
            "priority": effect_event.priority,
            "trigger_name": effect_event.trigger_name,
            "effect_roll": clash_result.get("tie_roll", null),
            "payload_summary": payload_summary,
        }
    ))

func _build_apply_field_change(before_field, field_state) -> Variant:
    var field_change = FieldChangeScript.new()
    field_change.change_kind = "apply"
    field_change.before_field_id = before_field.field_def_id if before_field != null else null
    field_change.after_field_id = field_state.field_def_id
    field_change.before_remaining_turns = before_field.remaining_turns if before_field != null else null
    field_change.after_remaining_turns = field_state.remaining_turns
    return field_change

func _resolve_creator_mp(battle_state, creator_id: String) -> int:
    if creator_id.is_empty():
        return -1
    var creator_unit = battle_state.get_unit(creator_id)
    if creator_unit == null:
        return -1
    return int(creator_unit.current_mp)

func _resolve_field_creator(effect_event) -> String:
    if effect_event != null and effect_event.owner_id != null:
        var owner_id := str(effect_event.owner_id)
        if not owner_id.is_empty():
            return owner_id
    if effect_event != null and effect_event.chain_context != null and effect_event.chain_context.actor_id != null:
        var actor_id := str(effect_event.chain_context.actor_id)
        if not actor_id.is_empty():
            return actor_id
    return ""

func _resolve_public_id_or_system(battle_state, source_id: String) -> String:
    if source_id.is_empty():
        return "system"
    var source_unit = battle_state.get_unit(source_id)
    if source_unit != null:
        return source_unit.public_id
    return source_id
