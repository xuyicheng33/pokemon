extends RefCounted
class_name TriggerBatchRunner

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var passive_skill_service
var passive_item_service
var field_service
var effect_instance_dispatcher
var effect_queue_service
var payload_executor
var rng_service
var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
    return last_invalid_battle_code

func execute_trigger_batch(
    trigger_name: String,
    battle_state,
    content_index,
    owner_unit_ids: Array,
    chain_context,
    extra_effect_events: Array = []
):
    last_invalid_battle_code = null
    var missing_dependency := resolve_missing_dependency()
    if not missing_dependency.is_empty():
        return ErrorCodesScript.INVALID_STATE_CORRUPTION
    var effect_events: Array = collect_trigger_events(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        chain_context,
        extra_effect_events
    )
    if last_invalid_battle_code != null:
        return last_invalid_battle_code
    if effect_events.is_empty():
        return null
    battle_state.pending_effect_queue = effect_events
    var sorted_events = effect_queue_service.sort_events(effect_events, rng_service)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    for effect_event in sorted_events:
        payload_executor.execute_effect_event(effect_event, battle_state, content_index)
        if payload_executor.invalid_battle_code() != null:
            battle_state.pending_effect_queue.clear()
            return payload_executor.invalid_battle_code()
    battle_state.pending_effect_queue.clear()
    return null

func collect_trigger_events(
    trigger_name: String,
    battle_state,
    content_index,
    owner_unit_ids: Array,
    chain_context,
    extra_effect_events: Array = []
) -> Array:
    last_invalid_battle_code = null
    var effect_events: Array = []
    effect_events.append_array(passive_skill_service.collect_trigger_events(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        chain_context
    ))
    if _capture_trigger_source_invalid_code(passive_skill_service):
        return []
    effect_events.append_array(passive_item_service.collect_trigger_events(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        chain_context
    ))
    if _capture_trigger_source_invalid_code(passive_item_service):
        return []
    effect_events.append_array(effect_instance_dispatcher.collect_trigger_events(
        trigger_name,
        battle_state,
        content_index,
        owner_unit_ids,
        chain_context
    ))
    if _capture_trigger_source_invalid_code(effect_instance_dispatcher):
        return []
    effect_events.append_array(field_service.collect_trigger_events(
        trigger_name,
        battle_state,
        content_index,
        chain_context
    ))
    if _capture_trigger_source_invalid_code(field_service):
        return []
    effect_events.append_array(extra_effect_events)
    return effect_events

func _capture_trigger_source_invalid_code(source_service) -> bool:
    if source_service == null:
        return false
    var invalid_code = _read_invalid_battle_code(source_service)
    if invalid_code == null:
        return false
    last_invalid_battle_code = invalid_code
    return true

func _read_invalid_battle_code(source_service) -> Variant:
    if source_service == null:
        return null
    return source_service.invalid_battle_code()

func resolve_missing_dependency() -> String:
    if passive_skill_service == null:
        return "passive_skill_service"
    if passive_item_service == null:
        return "passive_item_service"
    if field_service == null:
        return "field_service"
    if field_service.has_method("resolve_missing_dependency"):
        var field_missing := str(field_service.resolve_missing_dependency())
        if not field_missing.is_empty():
            return "field_service.%s" % field_missing
    if effect_instance_dispatcher == null:
        return "effect_instance_dispatcher"
    if effect_queue_service == null:
        return "effect_queue_service"
    if payload_executor == null:
        return "payload_executor"
    if payload_executor.has_method("resolve_missing_dependency"):
        var payload_missing := str(payload_executor.resolve_missing_dependency())
        if not payload_missing.is_empty():
            return "payload_executor.%s" % payload_missing
    if rng_service == null:
        return "rng_service"
    return ""
