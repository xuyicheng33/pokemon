extends RefCounted
class_name UnitState

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var unit_instance_id: String = ""
var public_id: String = ""
var definition_id: String = ""
var display_name: String = ""
var max_hp: int = 0
var current_hp: int = 0
var max_mp: int = 0
var current_mp: int = 0
var regen_per_turn: int = 0
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
var effect_instances: Array = []
var rule_mod_instances: Array = []
var has_acted: bool = false
var action_window_passed: bool = false
var leave_state: String = LeaveStatesScript.ACTIVE
var leave_reason: Variant = null
var last_effective_speed: int = 0

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
        "combat_type_ids": combat_type_ids,
        "base_attack": base_attack,
        "base_defense": base_defense,
        "base_sp_attack": base_sp_attack,
        "base_sp_defense": base_sp_defense,
        "base_speed": base_speed,
        "stat_stages": stat_stages,
        "effect_instances": effect_dicts,
        "rule_mod_instances": rule_mod_dicts,
        "has_acted": has_acted,
        "action_window_passed": action_window_passed,
        "leave_state": leave_state,
        "leave_reason": leave_reason,
        "last_effective_speed": last_effective_speed,
    }
