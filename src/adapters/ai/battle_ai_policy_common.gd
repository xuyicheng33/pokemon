extends RefCounted
class_name BattleAIPolicyCommon

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

static func find_side_snapshot(public_snapshot: Dictionary, side_id: String) -> Dictionary:
    for side_snapshot in public_snapshot.get("sides", []):
        if str(side_snapshot.get("side_id", "")) == side_id:
            return side_snapshot
    return {}

static func find_active_unit(public_snapshot: Dictionary, side_id: String) -> Dictionary:
    var side_snapshot := find_side_snapshot(public_snapshot, side_id)
    if side_snapshot.is_empty():
        return {}
    var active_public_id := str(side_snapshot.get("active_public_id", ""))
    for unit_snapshot in side_snapshot.get("team_units", []):
        if str(unit_snapshot.get("public_id", "")) == active_public_id:
            return unit_snapshot
    return {}

static func has_effect(unit_snapshot: Dictionary, effect_id: String) -> bool:
    for effect_snapshot in unit_snapshot.get("effect_instances", []):
        if str(effect_snapshot.get("effect_definition_id", "")) == effect_id:
            return true
    return false

static func count_effects(unit_snapshot: Dictionary, effect_id: String) -> int:
    var count := 0
    for effect_snapshot in unit_snapshot.get("effect_instances", []):
        if str(effect_snapshot.get("effect_definition_id", "")) == effect_id:
            count += 1
    return count

static func hp_ratio(unit_snapshot: Dictionary) -> float:
    var max_hp: int = max(1, int(unit_snapshot.get("max_hp", 1)))
    return float(int(unit_snapshot.get("current_hp", 0))) / float(max_hp)

static func has_legal_skill(legal_action_set, skill_id: String) -> bool:
    if skill_id.is_empty():
        return false
    return legal_action_set.legal_skill_ids.has(skill_id)

static func has_legal_ultimate(legal_action_set, skill_id: String) -> bool:
    if skill_id.is_empty():
        return false
    return legal_action_set.legal_ultimate_ids.has(skill_id)

static func choose_first_legal_skill(legal_action_set, skill_order: Array) -> Dictionary:
    for skill_id in skill_order:
        var candidate_id := String(skill_id)
        if has_legal_skill(legal_action_set, candidate_id):
            return {"command_type": CommandTypesScript.SKILL, "skill_id": candidate_id}
    return {}
