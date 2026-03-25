extends RefCounted
class_name ValueChange

var entity_id: String = ""
var resource_name: String = ""
var before_value: int = 0
var after_value: int = 0
var delta: int = 0

func to_stable_dict() -> Dictionary:
    return {
        "entity_id": entity_id,
        "resource_name": resource_name,
        "before_value": before_value,
        "after_value": after_value,
        "delta": delta,
    }
