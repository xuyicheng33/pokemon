extends RefCounted
class_name BattleState

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var battle_id: String = ""
@warning_ignore("shadowed_global_identifier")
var seed: int = 0
var rng_profile: String = ""
var format_id: String = ""
var visibility_mode: String = ""
var max_turn: int = 0
var max_chain_depth: int = 32
var battle_level: int = 0
var selection_deadline_ms: int = 30000
var turn_index: int = 0
var phase: String = BattlePhasesScript.BATTLE_INIT
var sides: Array = []
var field_state = null
var pending_effect_queue: Array = []
var chain_context = null
var battle_result = null
var rng_stream_index: int = 0
var fatal_damage_records_by_target: Dictionary = {}
var field_rule_mod_instances: Array = []
var last_matchup_signature: String = ""

func get_side(side_id: String):
    for side_state in sides:
        if side_state.side_id == side_id:
            return side_state
    return null

func get_opponent_side(side_id: String):
    for side_state in sides:
        if side_state.side_id != side_id:
            return side_state
    return null

func get_side_for_unit(unit_instance_id: String):
    for side_state in sides:
        if side_state.find_unit(unit_instance_id) != null:
            return side_state
    return null

func get_unit(unit_instance_id: String):
    var side_state = get_side_for_unit(unit_instance_id)
    if side_state == null:
        return null
    return side_state.find_unit(unit_instance_id)

func get_unit_by_public_id(public_id: String):
    for side_state in sides:
        for unit_state in side_state.team_units:
            if unit_state.public_id == public_id:
                return unit_state
    return null

func get_active_unit(side_id: String, slot_id: String = ContentSchemaScript.ACTIVE_SLOT_PRIMARY):
    var side_state = get_side(side_id)
    if side_state == null:
        return null
    return side_state.get_active_unit(slot_id)

func to_stable_dict() -> Dictionary:
    var side_dicts: Array = []
    var sorted_sides = sides.duplicate()
    sorted_sides.sort_custom(func(a, b): return a.side_id < b.side_id)
    for side_state in sorted_sides:
        side_dicts.append(side_state.to_stable_dict())
    var field_rule_mod_dicts: Array = []
    var sorted_field_rule_mods = field_rule_mod_instances.duplicate()
    sorted_field_rule_mods.sort_custom(func(a, b): return a.instance_id < b.instance_id)
    for rule_mod_instance in sorted_field_rule_mods:
        field_rule_mod_dicts.append(rule_mod_instance.to_stable_dict())
    return {
        "battle_id": battle_id,
        "seed": seed,
        "rng_profile": rng_profile,
        "format_id": format_id,
        "visibility_mode": visibility_mode,
        "max_turn": max_turn,
        "max_chain_depth": max_chain_depth,
        "battle_level": battle_level,
        "selection_deadline_ms": selection_deadline_ms,
        "turn_index": turn_index,
        "phase": phase,
        "sides": side_dicts,
        "field_state": field_state.to_stable_dict() if field_state != null else null,
        "field_rule_mod_instances": field_rule_mod_dicts,
        "last_matchup_signature": last_matchup_signature,
        "battle_result": battle_result.to_stable_dict() if battle_result != null else null,
        "rng_stream_index": rng_stream_index,
    }
