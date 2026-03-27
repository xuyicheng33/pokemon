extends RefCounted
class_name PayloadForcedReplaceHandler

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var replacement_service

var last_invalid_battle_code: Variant = null

func resolve_missing_dependency() -> String:
    if replacement_service == null:
        return "replacement_service"
    return ""

func execute(payload, effect_event, battle_state, content_index) -> bool:
    last_invalid_battle_code = null
    if not payload is ForcedReplacePayloadScript:
        return false
    var target_unit = _resolve_target_unit(payload.scope, effect_event, battle_state)
    if not _is_effect_target_valid(target_unit):
        return true
    if replacement_service == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return true
    var selector_reason: String = String(payload.selector_reason).strip_edges()
    if selector_reason.is_empty():
        selector_reason = "forced_replace"
    var replacement_result: Dictionary = replacement_service.execute_forced_replace(
        battle_state,
        content_index,
        target_unit.unit_instance_id,
        selector_reason
    )
    var invalid_code = replacement_result.get("invalid_code", null)
    if invalid_code != null:
        last_invalid_battle_code = invalid_code
    return true

func _resolve_target_unit(scope: String, effect_event, battle_state):
    match scope:
        "self":
            return battle_state.get_unit(effect_event.owner_id)
        "target":
            if effect_event.chain_context == null or effect_event.chain_context.target_unit_id == null:
                return null
            return battle_state.get_unit(str(effect_event.chain_context.target_unit_id))
        _:
            return null

func _is_effect_target_valid(target_unit) -> bool:
    return target_unit != null and target_unit.leave_state == LeaveStatesScript.ACTIVE and target_unit.current_hp > 0
