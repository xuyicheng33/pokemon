extends RefCounted
class_name FieldState

var field_def_id: String = ""
var instance_id: String = ""
var creator: String = ""
var remaining_turns: int = 0
var source_instance_id: String = ""
var source_kind_order: int = 0
var source_order_speed_snapshot: int = 0

func to_stable_dict() -> Dictionary:
    return {
        "field_def_id": field_def_id,
        "instance_id": instance_id,
        "creator": creator,
        "remaining_turns": remaining_turns,
        "source_instance_id": source_instance_id,
        "source_kind_order": source_kind_order,
        "source_order_speed_snapshot": source_order_speed_snapshot,
    }
