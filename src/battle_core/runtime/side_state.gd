extends RefCounted
class_name SideState

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var side_id: String = ""
var team_units: Array = []
var active_slots: Dictionary = {}
var bench_order: PackedStringArray = PackedStringArray()
var public_labels: Dictionary = {}
var selection_state = null

func find_unit(unit_instance_id: String):
    for unit_state in team_units:
        if unit_state.unit_instance_id == unit_instance_id:
            return unit_state
    return null

func find_unit_by_public_id(public_id: String):
    for unit_state in team_units:
        if unit_state.public_id == public_id:
            return unit_state
    return null

func get_active_unit(slot_id: String = ContentSchemaScript.ACTIVE_SLOT_PRIMARY):
    var unit_instance_id: String = active_slots.get(slot_id, "")
    if unit_instance_id.is_empty():
        return null
    return find_unit(unit_instance_id)

func set_active_unit(slot_id: String, unit_instance_id: String) -> void:
    active_slots[slot_id] = unit_instance_id

func clear_active_unit(slot_id: String = ContentSchemaScript.ACTIVE_SLOT_PRIMARY) -> void:
    active_slots.erase(slot_id)

func has_bench_unit(unit_instance_id: String) -> bool:
    return bench_order.has(unit_instance_id)

func to_stable_dict() -> Dictionary:
    var team_dicts: Array = []
    var sorted_units = team_units.duplicate()
    sorted_units.sort_custom(func(a, b): return a.public_id < b.public_id)
    for unit_state in sorted_units:
        team_dicts.append(unit_state.to_stable_dict())
    var slot_ids := active_slots.keys()
    slot_ids.sort()
    var active_slot_dicts: Array = []
    for slot_id in slot_ids:
        active_slot_dicts.append({
            "slot_id": slot_id,
            "unit_instance_id": active_slots[slot_id],
        })
    return {
        "side_id": side_id,
        "active_slots": active_slot_dicts,
        "bench_order": bench_order,
        "public_labels": public_labels,
        "team_units": team_dicts,
        "selection_state": selection_state.to_stable_dict() if selection_state != null else null,
    }
