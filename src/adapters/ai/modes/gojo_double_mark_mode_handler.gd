extends RefCounted
class_name GojoDoubleMarkModeHandler

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const BattleAIPolicyCommonScript := preload("res://src/adapters/ai/battle_ai_policy_common.gd")

static func choose_action(_actor: Dictionary, target: Dictionary, legal_action_set, role_policy: Dictionary) -> Dictionary:
    var combo_skill_id := str(role_policy.get("combo_skill_id", ""))
    var combo_marks: Array = role_policy.get("combo_marks", [])
    var has_all_marks := true
    for mark_id in combo_marks:
        if not BattleAIPolicyCommonScript.has_effect(target, String(mark_id)):
            has_all_marks = false
            break
    if has_all_marks and BattleAIPolicyCommonScript.has_legal_skill(legal_action_set, combo_skill_id):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": combo_skill_id}

    var mark_build_order: Array = role_policy.get("mark_build_order", [])
    for skill_id in mark_build_order:
        var candidate_id := String(skill_id)
        var mark_effect_id := "%s_mark" % _resolve_mark_key(candidate_id)
        if BattleAIPolicyCommonScript.has_legal_skill(legal_action_set, candidate_id) and not BattleAIPolicyCommonScript.has_effect(target, mark_effect_id):
            return {"command_type": CommandTypesScript.SKILL, "skill_id": candidate_id}

    var low_hp_finish_skill_id := str(role_policy.get("low_hp_finish_skill_id", ""))
    var low_hp_finish_threshold := float(role_policy.get("low_hp_finish_threshold", 0.0))
    if BattleAIPolicyCommonScript.has_legal_skill(legal_action_set, low_hp_finish_skill_id) and BattleAIPolicyCommonScript.hp_ratio(target) <= low_hp_finish_threshold:
        return {"command_type": CommandTypesScript.SKILL, "skill_id": low_hp_finish_skill_id}
    return {}

static func _resolve_mark_key(skill_id: String) -> String:
    if skill_id == "gojo_ao":
        return "gojo_ao"
    if skill_id == "gojo_aka":
        return "gojo_aka"
    return skill_id
