extends RefCounted
class_name RuleModInstance

var instance_id: String = ""
var mod_kind: String = ""
var mod_op: String = ""
var value = null
var scope: String = "self"
var duration_mode: String = "permanent"
var owner_scope: String = "unit"
var owner_id: String = ""
var remaining: int = 0
var created_turn: int = 0
var decrement_on: String = ""
var source_instance_id: String = ""
var source_kind_order: int = 0
var source_order_speed_snapshot: int = 0
var priority: int = 0

func to_stable_dict() -> Dictionary:
    return {
        "instance_id": instance_id,
        "mod_kind": mod_kind,
        "mod_op": mod_op,
        "value": value,
        "scope": scope,
        "duration_mode": duration_mode,
        "owner_scope": owner_scope,
        "owner_id": owner_id,
        "remaining": remaining,
        "created_turn": created_turn,
        "decrement_on": decrement_on,
        "source_instance_id": source_instance_id,
        "source_kind_order": source_kind_order,
        "source_order_speed_snapshot": source_order_speed_snapshot,
        "priority": priority,
    }
