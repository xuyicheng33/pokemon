extends RefCounted
class_name TargetSnapshot

var target_kind: String = ""
var target_unit_id: Variant = null
var target_slot: Variant = null

func to_stable_dict() -> Dictionary:
    return {
        "target_kind": target_kind,
        "target_unit_id": target_unit_id,
        "target_slot": target_slot,
    }
