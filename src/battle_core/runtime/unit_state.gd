extends RefCounted
class_name UnitState

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const STAT_STAGE_KEYS := ["attack", "defense", "sp_attack", "sp_defense", "speed"]

var unit_instance_id: String = ""
var public_id: String = ""
var definition_id: String = ""
var display_name: String = ""
var max_hp: int = 0
var current_hp: int = 0
var max_mp: int = 0
var current_mp: int = 0
var regen_per_turn: int = 0
var ultimate_points: int = 0
var ultimate_points_cap: int = 0
var ultimate_points_required: int = 0
var ultimate_point_gain_on_regular_skill_cast: int = 0
var regular_skill_ids: PackedStringArray = PackedStringArray()
var combat_type_ids: PackedStringArray = PackedStringArray()
var base_attack: int = 0
var base_defense: int = 0
var base_sp_attack: int = 0
var base_sp_defense: int = 0
var base_speed: int = 0
var stat_stages: Dictionary = {
    "attack": 0,
    "defense": 0,
    "sp_attack": 0,
    "sp_defense": 0,
    "speed": 0,
}
var persistent_stat_stages: Dictionary = {
    "attack": 0,
    "defense": 0,
    "sp_attack": 0,
    "sp_defense": 0,
    "speed": 0,
}
var effect_instances: Array = []
var rule_mod_instances: Array = []
var has_acted: bool = false
var action_window_passed: bool = false
var leave_state: String = LeaveStatesScript.ACTIVE
var leave_reason: Variant = null
var last_effective_speed: int = 0
var reentered_turn_index: int = -1
var used_once_per_battle_skill_ids: PackedStringArray = PackedStringArray()

func to_stable_dict() -> Dictionary:
    var effect_dicts: Array = []
    var sorted_effects = effect_instances.duplicate()
    sorted_effects.sort_custom(func(a, b): return a.instance_id < b.instance_id)
    for effect_instance in sorted_effects:
        effect_dicts.append(effect_instance.to_stable_dict())
    var rule_mod_dicts: Array = []
    var sorted_rule_mods = rule_mod_instances.duplicate()
    sorted_rule_mods.sort_custom(func(a, b): return a.instance_id < b.instance_id)
    for rule_mod_instance in sorted_rule_mods:
        rule_mod_dicts.append(rule_mod_instance.to_stable_dict())
    var sorted_used_once_per_battle_skill_ids := used_once_per_battle_skill_ids.duplicate()
    sorted_used_once_per_battle_skill_ids.sort()
    return {
        "unit_instance_id": unit_instance_id,
        "public_id": public_id,
        "definition_id": definition_id,
        "display_name": display_name,
        "max_hp": max_hp,
        "current_hp": current_hp,
        "max_mp": max_mp,
        "current_mp": current_mp,
        "regen_per_turn": regen_per_turn,
        "ultimate_points": ultimate_points,
        "ultimate_points_cap": ultimate_points_cap,
        "ultimate_points_required": ultimate_points_required,
        "ultimate_point_gain_on_regular_skill_cast": ultimate_point_gain_on_regular_skill_cast,
        "regular_skill_ids": regular_skill_ids,
        "combat_type_ids": combat_type_ids,
        "base_attack": base_attack,
        "base_defense": base_defense,
        "base_sp_attack": base_sp_attack,
        "base_sp_defense": base_sp_defense,
        "base_speed": base_speed,
        "stat_stages": stat_stages,
        "persistent_stat_stages": persistent_stat_stages,
        "effect_instances": effect_dicts,
        "rule_mod_instances": rule_mod_dicts,
        "has_acted": has_acted,
        "action_window_passed": action_window_passed,
        "leave_state": leave_state,
        "leave_reason": leave_reason,
        "last_effective_speed": last_effective_speed,
        "reentered_turn_index": reentered_turn_index,
        "used_once_per_battle_skill_ids": sorted_used_once_per_battle_skill_ids,
    }

func has_used_once_per_battle_skill(skill_id: String) -> bool:
    var normalized_skill_id := String(skill_id).strip_edges()
    if normalized_skill_id.is_empty():
        return false
    return used_once_per_battle_skill_ids.has(normalized_skill_id)

func mark_once_per_battle_skill_used(skill_id: String) -> void:
    var normalized_skill_id := String(skill_id).strip_edges()
    if normalized_skill_id.is_empty():
        return
    if used_once_per_battle_skill_ids.has(normalized_skill_id):
        return
    used_once_per_battle_skill_ids.append(normalized_skill_id)

func get_effective_stage(stat_name: String) -> int:
    var temporary_stage: int = int(stat_stages.get(stat_name, 0))
    var persistent_stage: int = int(persistent_stat_stages.get(stat_name, 0))
    return clamp(temporary_stage + persistent_stage, -2, 2)

func get_effective_stat_stage_map() -> Dictionary:
    var combined: Dictionary = {}
    for stat_name in STAT_STAGE_KEYS:
        combined[String(stat_name)] = get_effective_stage(String(stat_name))
    return combined

func reset_temporary_stat_stages() -> void:
    stat_stages = {
        "attack": 0,
        "defense": 0,
        "sp_attack": 0,
        "sp_defense": 0,
        "speed": 0,
    }

func clear_persistent_stat_stages() -> void:
    persistent_stat_stages = {
        "attack": 0,
        "defense": 0,
        "sp_attack": 0,
        "sp_defense": 0,
        "speed": 0,
    }
