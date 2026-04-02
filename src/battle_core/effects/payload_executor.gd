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

func _passes_effect_preconditions(effect_definition, effect_event, battle_state) -> bool:
    if not _passes_incoming_action_filters(effect_definition, effect_event):
        return false
    if not effect_definition.required_target_effects.is_empty():
        if effect_definition.scope != "target":
            last_invalid_battle_code = ErrorCodesScript.INVALID_EFFECT_DEFINITION
            return false
        var target_unit = _resolve_required_target(effect_event, battle_state)
        if not _is_required_target_valid(target_unit):
            return false
        var require_same_owner: bool = bool(effect_definition.required_target_same_owner)
        var required_owner_id := String(effect_event.owner_id if effect_event != null else "")
        for required_effect_id in effect_definition.required_target_effects:
            if not _target_has_required_effect(target_unit, String(required_effect_id), require_same_owner, required_owner_id):
                return false
    return true

func _passes_incoming_action_filters(effect_definition, effect_event) -> bool:
    var command_filters: PackedStringArray = effect_definition.required_incoming_command_types
    var combat_type_filters: PackedStringArray = effect_definition.required_incoming_combat_type_ids
    if command_filters.is_empty() and combat_type_filters.is_empty():
        return true
    if effect_event == null or effect_event.chain_context == null:
        return false
    var chain_context = effect_event.chain_context
    var incoming_command_type := String(chain_context.command_type if chain_context.command_type != null else "")
    var incoming_combat_type_id := String(chain_context.action_combat_type_id if chain_context.action_combat_type_id != null else "")
    if not command_filters.is_empty() and not command_filters.has(incoming_command_type):
        return false
    if not combat_type_filters.is_empty() and not combat_type_filters.has(incoming_combat_type_id):
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

func _target_has_required_effect(target_unit, effect_definition_id: String, require_same_owner: bool, required_owner_id: String) -> bool:
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id != effect_definition_id:
            continue
        if not require_same_owner:
            return true
        var source_owner_id := String(effect_instance.meta.get("source_owner_id", ""))
        if not source_owner_id.is_empty() and source_owner_id == required_owner_id:
            return true
    return false
