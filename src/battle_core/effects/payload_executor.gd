extends RefCounted
class_name PayloadExecutor

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var effect_precondition_service
var payload_handler_registry

var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
    return last_invalid_battle_code

func resolve_missing_dependency() -> String:
    if effect_precondition_service == null:
        return "effect_precondition_service"
    var precondition_missing := _resolve_handler_missing(effect_precondition_service)
    if not precondition_missing.is_empty():
        return "effect_precondition_service.%s" % precondition_missing
    if payload_handler_registry == null:
        return "payload_handler_registry"
    var registry_missing := _resolve_handler_missing(payload_handler_registry)
    if not registry_missing.is_empty():
        return "payload_handler_registry.%s" % registry_missing
    return ""

func execute_effect_event(
    effect_event,
    battle_state,
    content_index,
    execute_trigger_batch: Callable = Callable()
) -> void:
    last_invalid_battle_code = null
    var missing_dependency := resolve_missing_dependency()
    if not missing_dependency.is_empty():
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return
    if not _enter_effect_guard(effect_event, battle_state):
        return
    var effect_definition = content_index.effects.get(effect_event.effect_definition_id)
    if effect_definition == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
        _leave_effect_guard(battle_state)
        return
    if not effect_precondition_service.passes_effect_preconditions(effect_definition, effect_event, battle_state):
        _capture_handler_invalid_code(effect_precondition_service)
        _leave_effect_guard(battle_state)
        return
    for payload in effect_definition.payloads:
        execute_payload(
            payload,
            effect_definition,
            effect_event,
            battle_state,
            content_index,
            execute_trigger_batch
        )
        if last_invalid_battle_code != null:
            _leave_effect_guard(battle_state)
            return
    _leave_effect_guard(battle_state)

func execute_payload(
    payload,
    effect_definition,
    effect_event,
    battle_state,
    content_index,
    execute_trigger_batch: Callable = Callable()
) -> void:
    var handler = payload_handler_registry.handler_for(payload)
    if handler == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
        return
    handler.execute(
        payload,
        effect_definition,
        effect_event,
        battle_state,
        content_index,
        execute_trigger_batch
    )
    _capture_handler_invalid_code(handler)
    if last_invalid_battle_code != null:
        return

func _capture_handler_invalid_code(handler) -> void:
    if handler == null:
        return
    var invalid_code = handler.invalid_battle_code()
    if invalid_code != null:
        last_invalid_battle_code = invalid_code

func _resolve_handler_missing(handler) -> String:
    if handler == null:
        return ""
    if handler.has_method("resolve_missing_dependency"):
        return str(handler.resolve_missing_dependency())
    return ""

func _enter_effect_guard(effect_event, battle_state) -> bool:
    if battle_state.chain_context == null or battle_state.max_chain_depth <= 0:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return false
    var dedupe_key := _build_dedupe_key(effect_event)
    if battle_state.chain_context.effect_dedupe_keys.has(dedupe_key):
        last_invalid_battle_code = ErrorCodesScript.INVALID_CHAIN_DEPTH
        return false
    battle_state.chain_context.effect_dedupe_keys[dedupe_key] = true
    battle_state.chain_context.chain_depth += 1
    if battle_state.chain_context.chain_depth > battle_state.max_chain_depth:
        battle_state.chain_context.chain_depth -= 1
        battle_state.chain_context.effect_dedupe_keys.erase(dedupe_key)
        last_invalid_battle_code = ErrorCodesScript.INVALID_CHAIN_DEPTH
        return false
    return true

func _leave_effect_guard(battle_state) -> void:
    if battle_state.chain_context == null:
        return
    if battle_state.chain_context.chain_depth > 0:
        battle_state.chain_context.chain_depth -= 1

func _build_dedupe_key(effect_event) -> String:
    var target_unit_id := ""
    if effect_event != null and effect_event.chain_context != null:
        target_unit_id = _string_or_empty(effect_event.chain_context.target_unit_id)
    return "%s|%s|%s|%s|%s|%s" % [
        _string_or_empty(effect_event.source_instance_id if effect_event != null else null),
        _string_or_empty(effect_event.effect_instance_id if effect_event != null else null),
        _string_or_empty(effect_event.trigger_name if effect_event != null else null),
        _string_or_empty(effect_event.effect_definition_id if effect_event != null else null),
        _string_or_empty(effect_event.owner_id if effect_event != null else null),
        target_unit_id,
    ]

func _string_or_empty(value) -> String:
    return "" if value == null else str(value)
