extends RefCounted
class_name PayloadForcedReplaceHandler

const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var replacement_service
var target_helper

var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
    return last_invalid_battle_code

func resolve_missing_dependency() -> String:
    if replacement_service == null:
        return "replacement_service"
    if target_helper == null:
        return "target_helper"
    return ""

func execute(payload, _effect_definition, effect_event, battle_state, content_index) -> void:
    last_invalid_battle_code = null
    if not payload is ForcedReplacePayloadScript:
        return
    var target_unit = target_helper.resolve_target_unit(payload.scope, effect_event, battle_state)
    if not target_helper.is_effect_target_valid(target_unit, payload.scope, effect_event):
        return
    if replacement_service == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return
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
