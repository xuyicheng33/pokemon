extends RefCounted
class_name SukunaKamadoCycleModeHandler

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const BattleAIPolicyCommonScript := preload("res://src/adapters/ai/battle_ai_policy_common.gd")

static func choose_action(actor: Dictionary, target: Dictionary, legal_action_set, role_policy: Dictionary) -> Dictionary:
    var points: int = int(actor.get("ultimate_points", 0))
    var required_points: int = max(1, int(actor.get("ultimate_points_required", 3)))
    if points < required_points:
        var point_rush_choice := BattleAIPolicyCommonScript.choose_first_legal_skill(legal_action_set, role_policy.get("point_rush_skill_order", []))
        if not point_rush_choice.is_empty():
            return point_rush_choice

    var kamado_mark_id := str(role_policy.get("kamado_mark_id", ""))
    var kamado_skill_id := str(role_policy.get("kamado_skill_id", ""))
    var kamado_count: int = BattleAIPolicyCommonScript.count_effects(target, kamado_mark_id)
    if BattleAIPolicyCommonScript.has_legal_skill(legal_action_set, kamado_skill_id) \
    and kamado_count < int(role_policy.get("kamado_prefer_max_stacks", 2)) \
    and BattleAIPolicyCommonScript.hp_ratio(target) > float(role_policy.get("kamado_target_hp_min", 0.25)) \
    and BattleAIPolicyCommonScript.hp_ratio(actor) > float(role_policy.get("kamado_self_hp_min", 0.45)):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": kamado_skill_id}

    var mp_adv_skill_id := str(role_policy.get("mp_adv_skill_id", ""))
    var mp_adv_margin: int = int(role_policy.get("mp_adv_margin", 8))
    if BattleAIPolicyCommonScript.has_legal_skill(legal_action_set, mp_adv_skill_id) and int(actor.get("current_mp", 0)) >= int(target.get("current_mp", 0)) + mp_adv_margin:
        return {"command_type": CommandTypesScript.SKILL, "skill_id": mp_adv_skill_id}
    return {}
