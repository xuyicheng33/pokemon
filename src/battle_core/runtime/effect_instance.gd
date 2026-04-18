extends RefCounted
class_name EffectInstance

var instance_id: String = ""
var def_id: String = ""
var owner: String = ""
var remaining: int = 0
var created_turn: int = 0
var source_instance_id: String = ""
var source_kind_order: int = 0
var source_order_speed_snapshot: int = 0
var persists_on_switch: bool = false
var meta: Dictionary = {}

func to_stable_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"def_id": def_id,
		"owner": owner,
		"remaining": remaining,
		"created_turn": created_turn,
		"source_instance_id": source_instance_id,
		"source_kind_order": source_kind_order,
		"source_order_speed_snapshot": source_order_speed_snapshot,
		"persists_on_switch": persists_on_switch,
		"meta": meta,
	}
