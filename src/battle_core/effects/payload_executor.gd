extends RefCounted
class_name PayloadExecutor

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var numeric_payload_handler
var state_payload_handler
var forced_replace_payload_handler

var last_invalid_battle_code: Variant = null

func resolve_missing_dependency() -> String:
    if numeric_payload_handler == null:
        return "numeric_payload_handler"
    var numeric_missing := _resolve_handler_missing(numeric_payload_handler)
    if not numeric_missing.is_empty():
        return "numeric_payload_handler.%s" % numeric_missing
    if state_payload_handler == null:
        return "state_payload_handler"
    var state_missing := _resolve_handler_missing(state_payload_handler)
    if not state_missing.is_empty():
        return "state_payload_handler.%s" % state_missing
    if forced_replace_payload_handler == null:
        return "forced_replace_payload_handler"
    var forced_missing := _resolve_handler_missing(forced_replace_payload_handler)
    if not forced_missing.is_empty():
        return "forced_replace_payload_handler.%s" % forced_missing
    return ""

func execute_effect_event(effect_event, battle_state, content_index) -> void:
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
    if not _passes_effect_preconditions(effect_definition, effect_event, battle_state):
        _leave_effect_guard(battle_state)
        return
    for payload in effect_definition.payloads:
        execute_payload(payload, effect_definition, effect_event, battle_state, content_index)
        if last_invalid_battle_code != null:
            _leave_effect_guard(battle_state)
            return
    _leave_effect_guard(battle_state)

func execute_payload(payload, effect_definition, effect_event, battle_state, content_index) -> void:
    if numeric_payload_handler.execute(payload, effect_definition, effect_event, battle_state, content_index):
        _capture_handler_invalid_code(numeric_payload_handler)
        return
    if state_payload_handler.execute(payload, effect_definition, effect_event, battle_state, content_index):
        _capture_handler_invalid_code(state_payload_handler)
        return
    if forced_replace_payload_handler.execute(payload, effect_event, battle_state, content_index):
        _capture_handler_invalid_code(forced_replace_payload_handler)
        return
    last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION

func _capture_handler_invalid_code(handler) -> void:
    if handler == null:
        return
    if handler.last_invalid_battle_code != null:
        last_invalid_battle_code = handler.last_invalid_battle_code

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
    var dedupe_key := "%s|%s|%s" % [effect_event.source_instance_id, effect_event.trigger_name, effect_event.event_id]
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

func _passes_effect_preconditions(effect_definition, effect_event, battle_state) -> bool:
    if effect_definition.required_target_effects.is_empty():
        return true
    if effect_definition.scope != "target":
        last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
        return false
    var target_unit = _resolve_required_target(effect_event, battle_state)
    if not _is_required_target_valid(target_unit):
        return false
    for required_effect_id in effect_definition.required_target_effects:
        if not _target_has_effect(target_unit, String(required_effect_id)):
            return false
    return true

func _resolve_required_target(effect_event, battle_state):
    if effect_event == null or effect_event.chain_context == null:
        return null
    var target_unit_id := str(effect_event.chain_context.target_unit_id)
    if target_unit_id.is_empty():
        return null
    return battle_state.get_unit(target_unit_id)

func _is_required_target_valid(target_unit) -> bool:
    return target_unit != null and target_unit.leave_state == LeaveStatesScript.ACTIVE and target_unit.current_hp > 0

func _target_has_effect(target_unit, effect_definition_id: String) -> bool:
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == effect_definition_id:
            return true
    return false
