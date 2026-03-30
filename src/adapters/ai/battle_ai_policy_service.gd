extends RefCounted
class_name BattleAIPolicyService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const BattleAIRolePolicyCatalogScript := preload("res://src/adapters/ai/battle_ai_role_policy_catalog.gd")

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
    var actor := _find_active_unit(public_snapshot, side_id)
    if actor.is_empty():
        return _choose_naive(legal_action_set, public_snapshot, side_id)
    var actor_def_id := str(actor.get("definition_id", ""))
    var role_policy: Dictionary = BattleAIRolePolicyCatalogScript.get_policy(actor_def_id)
    if role_policy.is_empty():
        return _choose_naive(legal_action_set, public_snapshot, side_id)
    var opponent_side_id := "P2" if side_id == "P1" else "P1"
    var target := _find_active_unit(public_snapshot, opponent_side_id)
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
    var hp_ratio := _hp_ratio(actor)
    if _has_legal_skill(legal_action_set, heal_skill_id) \
    and hp_ratio <= heal_threshold \
    and int(actor.get("current_hp", 0)) < int(actor.get("max_hp", 0)):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": heal_skill_id}

    var mode := str(role_policy.get("mode", ""))
    if mode == "double_mark_combo":
        var gojo_choice := _choose_double_mark_combo_action(target, legal_action_set, role_policy)
        if not gojo_choice.is_empty():
            return gojo_choice
    elif mode == "kamado_cycle":
        var sukuna_choice := _choose_kamado_cycle_action(actor, target, legal_action_set, role_policy)
        if not sukuna_choice.is_empty():
            return sukuna_choice

    return _choose_first_legal_skill(legal_action_set, role_policy.get("fallback_skill_order", []))

func _choose_double_mark_combo_action(target: Dictionary, legal_action_set, role_policy: Dictionary) -> Dictionary:
    var combo_skill_id := str(role_policy.get("combo_skill_id", ""))
    var combo_marks: Array = role_policy.get("combo_marks", [])
    var has_all_marks := true
    for mark_id in combo_marks:
        if not _has_effect(target, String(mark_id)):
            has_all_marks = false
            break
    if has_all_marks and _has_legal_skill(legal_action_set, combo_skill_id):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": combo_skill_id}

    var mark_build_order: Array = role_policy.get("mark_build_order", [])
    for skill_id in mark_build_order:
        if _has_legal_skill(legal_action_set, String(skill_id)) and not _has_effect(target, "%s_mark" % _resolve_mark_key(skill_id)):
            return {"command_type": CommandTypesScript.SKILL, "skill_id": String(skill_id)}

    var low_hp_finish_skill_id := str(role_policy.get("low_hp_finish_skill_id", ""))
    var low_hp_finish_threshold := float(role_policy.get("low_hp_finish_threshold", 0.0))
    if _has_legal_skill(legal_action_set, low_hp_finish_skill_id) and _hp_ratio(target) <= low_hp_finish_threshold:
        return {"command_type": CommandTypesScript.SKILL, "skill_id": low_hp_finish_skill_id}
    return {}

func _resolve_mark_key(skill_id: String) -> String:
    if skill_id == "gojo_ao":
        return "gojo_ao"
    if skill_id == "gojo_aka":
        return "gojo_aka"
    return skill_id

func _choose_kamado_cycle_action(actor: Dictionary, target: Dictionary, legal_action_set, role_policy: Dictionary) -> Dictionary:
    var points: int = int(actor.get("ultimate_points", 0))
    var required_points: int = max(1, int(actor.get("ultimate_points_required", 3)))
    if points < required_points:
        var point_rush_choice := _choose_first_legal_skill(legal_action_set, role_policy.get("point_rush_skill_order", []))
        if not point_rush_choice.is_empty():
            return point_rush_choice

    var kamado_mark_id := str(role_policy.get("kamado_mark_id", ""))
    var kamado_skill_id := str(role_policy.get("kamado_skill_id", ""))
    var kamado_count: int = _count_effects(target, kamado_mark_id)
    if _has_legal_skill(legal_action_set, kamado_skill_id) \
    and kamado_count < int(role_policy.get("kamado_prefer_max_stacks", 2)) \
    and _hp_ratio(target) > float(role_policy.get("kamado_target_hp_min", 0.25)) \
    and _hp_ratio(actor) > float(role_policy.get("kamado_self_hp_min", 0.45)):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": kamado_skill_id}

    var mp_adv_skill_id := str(role_policy.get("mp_adv_skill_id", ""))
    var mp_adv_margin: int = int(role_policy.get("mp_adv_margin", 8))
    if _has_legal_skill(legal_action_set, mp_adv_skill_id) and int(actor.get("current_mp", 0)) >= int(target.get("current_mp", 0)) + mp_adv_margin:
        return {"command_type": CommandTypesScript.SKILL, "skill_id": mp_adv_skill_id}
    return {}

func _choose_first_legal_skill(legal_action_set, skill_order: Array) -> Dictionary:
    for skill_id in skill_order:
        if _has_legal_skill(legal_action_set, String(skill_id)):
            return {"command_type": CommandTypesScript.SKILL, "skill_id": String(skill_id)}
    return {}

func _best_switch_target(public_snapshot: Dictionary, side_id: String, legal_targets: PackedStringArray) -> String:
    if public_snapshot.is_empty() or side_id.is_empty():
        return str(legal_targets[0])
    var side_snapshot := _find_side_snapshot(public_snapshot, side_id)
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

func _find_side_snapshot(public_snapshot: Dictionary, side_id: String) -> Dictionary:
    for side_snapshot in public_snapshot.get("sides", []):
        if str(side_snapshot.get("side_id", "")) == side_id:
            return side_snapshot
    return {}

func _find_active_unit(public_snapshot: Dictionary, side_id: String) -> Dictionary:
    var side_snapshot := _find_side_snapshot(public_snapshot, side_id)
    if side_snapshot.is_empty():
        return {}
    var active_public_id := str(side_snapshot.get("active_public_id", ""))
    for unit_snapshot in side_snapshot.get("team_units", []):
        if str(unit_snapshot.get("public_id", "")) == active_public_id:
            return unit_snapshot
    return {}

func _has_effect(unit_snapshot: Dictionary, effect_id: String) -> bool:
    for effect_snapshot in unit_snapshot.get("effect_instances", []):
        if str(effect_snapshot.get("effect_definition_id", "")) == effect_id:
            return true
    return false

func _count_effects(unit_snapshot: Dictionary, effect_id: String) -> int:
    var count := 0
    for effect_snapshot in unit_snapshot.get("effect_instances", []):
        if str(effect_snapshot.get("effect_definition_id", "")) == effect_id:
            count += 1
    return count

func _hp_ratio(unit_snapshot: Dictionary) -> float:
    var max_hp: int = max(1, int(unit_snapshot.get("max_hp", 1)))
    return float(int(unit_snapshot.get("current_hp", 0))) / float(max_hp)

func _has_legal_skill(legal_action_set, skill_id: String) -> bool:
    if skill_id.is_empty():
        return false
    return legal_action_set.legal_skill_ids.has(skill_id)

func _has_legal_ultimate(legal_action_set, skill_id: String) -> bool:
    if skill_id.is_empty():
        return false
    return legal_action_set.legal_ultimate_ids.has(skill_id)

func _choose_domain_when_ready(legal_action_set, public_snapshot: Dictionary, side_id: String, skill_id: String) -> Dictionary:
    if not _has_legal_ultimate(legal_action_set, skill_id):
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
    var side_snapshot := _find_side_snapshot(public_snapshot, side_id)
    for unit_snapshot in side_snapshot.get("team_units", []):
        if str(unit_snapshot.get("public_id", "")) == creator_public_id:
            return true
    return false
