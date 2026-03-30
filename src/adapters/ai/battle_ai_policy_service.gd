extends RefCounted
class_name BattleAIPolicyService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const BattleAIRolePolicyCatalogScript := preload("res://src/adapters/ai/battle_ai_role_policy_catalog.gd")
const BattleAIPolicyCommonScript := preload("res://src/adapters/ai/battle_ai_policy_common.gd")

func choose_command(legal_action_set, public_snapshot: Dictionary = {}, side_id: String = "", policy: String = "heuristic") -> Dictionary:
    if legal_action_set == null:
        return {}
    if not str(legal_action_set.forced_command_type).is_empty():
        # Forced command injection is owned by turn_selection_resolver.
        return {}
    if policy == "naive":
        return _choose_naive(legal_action_set, public_snapshot, side_id)
    var heuristic_choice = _choose_heuristic(legal_action_set, public_snapshot, side_id)
    if not heuristic_choice.is_empty():
        return heuristic_choice
    return _choose_naive(legal_action_set, public_snapshot, side_id)

func _choose_naive(legal_action_set, public_snapshot: Dictionary, side_id: String) -> Dictionary:
    if not legal_action_set.legal_skill_ids.is_empty():
        return {"command_type": CommandTypesScript.SKILL, "skill_id": str(legal_action_set.legal_skill_ids[0])}
    if not legal_action_set.legal_ultimate_ids.is_empty():
        return {"command_type": CommandTypesScript.ULTIMATE, "skill_id": str(legal_action_set.legal_ultimate_ids[0])}
    if not legal_action_set.legal_switch_target_public_ids.is_empty():
        return {
            "command_type": CommandTypesScript.SWITCH,
            "target_public_id": _best_switch_target(public_snapshot, side_id, legal_action_set.legal_switch_target_public_ids),
        }
    if bool(legal_action_set.wait_allowed):
        return {"command_type": CommandTypesScript.WAIT}
    return {}

func _choose_heuristic(legal_action_set, public_snapshot: Dictionary, side_id: String) -> Dictionary:
    if public_snapshot.is_empty() or side_id.is_empty():
        return _choose_naive(legal_action_set, public_snapshot, side_id)
    var actor := BattleAIPolicyCommonScript.find_active_unit(public_snapshot, side_id)
    if actor.is_empty():
        return _choose_naive(legal_action_set, public_snapshot, side_id)
    var actor_def_id := str(actor.get("definition_id", ""))
    var role_policy: Dictionary = BattleAIRolePolicyCatalogScript.get_policy(actor_def_id)
    if role_policy.is_empty():
        return _choose_naive(legal_action_set, public_snapshot, side_id)
    var opponent_side_id := "P2" if side_id == "P1" else "P1"
    var target := BattleAIPolicyCommonScript.find_active_unit(public_snapshot, opponent_side_id)
    return _choose_role_action(actor, target, legal_action_set, public_snapshot, side_id, role_policy)

func _choose_role_action(
    actor: Dictionary,
    target: Dictionary,
    legal_action_set,
    public_snapshot: Dictionary,
    side_id: String,
    role_policy: Dictionary
) -> Dictionary:
    var domain_skill_id := str(role_policy.get("domain_ultimate_id", ""))
    var domain_choice := _choose_domain_when_ready(legal_action_set, public_snapshot, side_id, domain_skill_id)
    if not domain_choice.is_empty():
        return domain_choice

    var heal_skill_id := str(role_policy.get("heal_skill_id", ""))
    var heal_threshold: float = float(role_policy.get("heal_threshold", 0.0))
    var hp_ratio := BattleAIPolicyCommonScript.hp_ratio(actor)
    if BattleAIPolicyCommonScript.has_legal_skill(legal_action_set, heal_skill_id) \
    and hp_ratio <= heal_threshold \
    and int(actor.get("current_hp", 0)) < int(actor.get("max_hp", 0)):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": heal_skill_id}

    var mode_choice := BattleAIRolePolicyCatalogScript.choose_mode_action(actor, target, legal_action_set, role_policy)
    if not mode_choice.is_empty():
        return mode_choice

    return BattleAIPolicyCommonScript.choose_first_legal_skill(legal_action_set, role_policy.get("fallback_skill_order", []))

func _best_switch_target(public_snapshot: Dictionary, side_id: String, legal_targets: PackedStringArray) -> String:
    if public_snapshot.is_empty() or side_id.is_empty():
        return str(legal_targets[0])
    var side_snapshot := BattleAIPolicyCommonScript.find_side_snapshot(public_snapshot, side_id)
    if side_snapshot.is_empty():
        return str(legal_targets[0])
    var best_target := ""
    var best_hp := -1
    for unit_snapshot in side_snapshot.get("team_units", []):
        var public_id := str(unit_snapshot.get("public_id", ""))
        if not legal_targets.has(public_id):
            continue
        var current_hp := int(unit_snapshot.get("current_hp", 0))
        if current_hp > best_hp:
            best_hp = current_hp
            best_target = public_id
    return best_target if not best_target.is_empty() else str(legal_targets[0])

func _choose_domain_when_ready(legal_action_set, public_snapshot: Dictionary, side_id: String, skill_id: String) -> Dictionary:
    if not BattleAIPolicyCommonScript.has_legal_ultimate(legal_action_set, skill_id):
        return {}
    if _has_owned_active_domain(public_snapshot, side_id):
        return {}
    return {"command_type": CommandTypesScript.ULTIMATE, "skill_id": skill_id}

func _has_owned_active_domain(public_snapshot: Dictionary, side_id: String) -> bool:
    var field_snapshot: Dictionary = public_snapshot.get("field", {})
    if str(field_snapshot.get("field_kind", "")) != "domain":
        return false
    var creator_side_id := str(field_snapshot.get("creator_side_id", ""))
    if not creator_side_id.is_empty():
        return creator_side_id == side_id
    var creator_public_id := str(field_snapshot.get("creator_public_id", ""))
    if creator_public_id.is_empty():
        return false
    var side_snapshot := BattleAIPolicyCommonScript.find_side_snapshot(public_snapshot, side_id)
    for unit_snapshot in side_snapshot.get("team_units", []):
        if str(unit_snapshot.get("public_id", "")) == creator_public_id:
            return true
    return false
