extends RefCounted
class_name BattleAIPolicyService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

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
    var opponent_side_id := "P2" if side_id == "P1" else "P1"
    var target := _find_active_unit(public_snapshot, opponent_side_id)
    var actor_def_id := str(actor.get("definition_id", ""))
    if actor_def_id == "gojo_satoru":
        return _choose_gojo_action(actor, target, legal_action_set, public_snapshot, side_id)
    if actor_def_id == "sukuna":
        return _choose_sukuna_action(actor, target, legal_action_set, public_snapshot, side_id)
    return _choose_naive(legal_action_set, public_snapshot, side_id)

func _choose_gojo_action(actor: Dictionary, target: Dictionary, legal_action_set, public_snapshot: Dictionary, side_id: String) -> Dictionary:
    var domain_choice := _choose_domain_when_ready(actor, target, legal_action_set, public_snapshot, side_id, "gojo_unlimited_void")
    if not domain_choice.is_empty():
        return domain_choice
    var hp_ratio := _hp_ratio(actor)
    if _has_legal_skill(legal_action_set, "gojo_reverse_ritual") and hp_ratio <= 0.35 and int(actor.get("current_hp", 0)) < int(actor.get("max_hp", 0)):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "gojo_reverse_ritual"}
    var has_ao_mark := _has_effect(target, "gojo_ao_mark")
    var has_aka_mark := _has_effect(target, "gojo_aka_mark")
    if has_ao_mark and has_aka_mark and _has_legal_skill(legal_action_set, "gojo_murasaki"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "gojo_murasaki"}
    if not has_ao_mark and _has_legal_skill(legal_action_set, "gojo_ao"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "gojo_ao"}
    if not has_aka_mark and _has_legal_skill(legal_action_set, "gojo_aka"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "gojo_aka"}
    if _has_legal_skill(legal_action_set, "gojo_murasaki") and _hp_ratio(target) <= 0.45:
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "gojo_murasaki"}
    if _has_legal_skill(legal_action_set, "gojo_aka"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "gojo_aka"}
    if _has_legal_skill(legal_action_set, "gojo_ao"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "gojo_ao"}
    return _choose_naive(legal_action_set, public_snapshot, side_id)

func _choose_sukuna_action(actor: Dictionary, target: Dictionary, legal_action_set, public_snapshot: Dictionary, side_id: String) -> Dictionary:
    var domain_choice := _choose_domain_when_ready(actor, target, legal_action_set, public_snapshot, side_id, "sukuna_fukuma_mizushi")
    if not domain_choice.is_empty():
        return domain_choice
    var hp_ratio: float = _hp_ratio(actor)
    if _has_legal_skill(legal_action_set, "sukuna_reverse_ritual") and hp_ratio <= 0.40 and int(actor.get("current_hp", 0)) < int(actor.get("max_hp", 0)):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_reverse_ritual"}

    var points: int = int(actor.get("ultimate_points", 0))
    var required_points: int = max(1, int(actor.get("ultimate_points_required", 3)))
    if points < required_points:
        if _has_legal_skill(legal_action_set, "sukuna_kai"):
            return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_kai"}
        if _has_legal_skill(legal_action_set, "sukuna_hatsu"):
            return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_hatsu"}
        if _has_legal_skill(legal_action_set, "sukuna_hiraku"):
            return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_hiraku"}

    var kamado_count: int = _count_effects(target, "sukuna_kamado_mark")
    if _has_legal_skill(legal_action_set, "sukuna_hiraku") and kamado_count < 2 and _hp_ratio(target) > 0.25 and hp_ratio > 0.45:
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_hiraku"}
    if _has_legal_skill(legal_action_set, "sukuna_hatsu") and int(actor.get("current_mp", 0)) >= int(target.get("current_mp", 0)) + 8:
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_hatsu"}
    if _has_legal_skill(legal_action_set, "sukuna_kai"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_kai"}
    if _has_legal_skill(legal_action_set, "sukuna_hatsu"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_hatsu"}
    if _has_legal_skill(legal_action_set, "sukuna_hiraku"):
        return {"command_type": CommandTypesScript.SKILL, "skill_id": "sukuna_hiraku"}
    return _choose_naive(legal_action_set, public_snapshot, side_id)

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
    return legal_action_set.legal_skill_ids.has(skill_id)

func _has_legal_ultimate(legal_action_set, skill_id: String) -> bool:
    return legal_action_set.legal_ultimate_ids.has(skill_id)

func _choose_domain_when_ready(actor: Dictionary, target: Dictionary, legal_action_set, public_snapshot: Dictionary, side_id: String, skill_id: String) -> Dictionary:
    if not _has_legal_ultimate(legal_action_set, skill_id):
        return {}
    if _field_owned_by_side(public_snapshot, side_id):
        return {}
    return {"command_type": CommandTypesScript.ULTIMATE, "skill_id": skill_id}

func _field_owned_by_side(public_snapshot: Dictionary, side_id: String) -> bool:
    var field_snapshot: Dictionary = public_snapshot.get("field", {})
    var creator_public_id := str(field_snapshot.get("creator_public_id", ""))
    if creator_public_id.is_empty():
        return false
    var side_snapshot := _find_side_snapshot(public_snapshot, side_id)
    for unit_snapshot in side_snapshot.get("team_units", []):
        if str(unit_snapshot.get("public_id", "")) == creator_public_id:
            return true
    return false
