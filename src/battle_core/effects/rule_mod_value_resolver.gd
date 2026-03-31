extends RefCounted
class_name RuleModValueResolver

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var last_error_code: Variant = null

func resolve_value(rule_mod_payload, effect_event, battle_state):
    last_error_code = null
    if rule_mod_payload == null:
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return null
    var formula := String(rule_mod_payload.dynamic_value_formula)
    if formula.is_empty():
        return rule_mod_payload.value
    match formula:
        ContentSchemaScript.RULE_MOD_VALUE_FORMULA_MATCHUP_BST_GAP_BAND:
            return _resolve_matchup_bst_gap_band(rule_mod_payload, effect_event, battle_state)
        _:
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return null

func _resolve_matchup_bst_gap_band(rule_mod_payload, effect_event, battle_state):
    var owner_id := ""
    if effect_event != null and effect_event.owner_id != null:
        owner_id = str(effect_event.owner_id)
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return null
    var owner_side = battle_state.get_side_for_unit(owner_id)
    if owner_side == null:
        last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return null
    var opponent_side = battle_state.get_opponent_side(owner_side.side_id)
    if opponent_side == null:
        last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return null
    var opponent_unit = opponent_side.get_active_unit()
    if opponent_unit == null:
        last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return null
    var gap: int = abs(_sum_unit_bst(owner_unit) - _sum_unit_bst(opponent_unit))
    var thresholds: PackedInt32Array = rule_mod_payload.dynamic_value_thresholds
    var outputs: PackedFloat32Array = rule_mod_payload.dynamic_value_outputs
    for index in range(thresholds.size()):
        if gap <= int(thresholds[index]):
            return float(outputs[index])
    return float(rule_mod_payload.dynamic_value_default)

func _sum_unit_bst(unit_state) -> int:
    if unit_state == null:
        return 0
    # 正式 BST 口径把 max_mp 视为第七维；宿傩回蓝公式与设计稿都依赖这个假设。
    return int(unit_state.max_hp) \
    + int(unit_state.base_attack) \
    + int(unit_state.base_defense) \
    + int(unit_state.base_sp_attack) \
    + int(unit_state.base_sp_defense) \
    + int(unit_state.base_speed) \
    + int(unit_state.max_mp)
