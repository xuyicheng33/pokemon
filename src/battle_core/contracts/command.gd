extends RefCounted
class_name Command

var command_id: String = ""
var turn_index: int = 1
var command_type: String = ""
var command_source: String = ""
var side_id: String = ""
var actor_id: String = ""
var actor_public_id: String = ""
var skill_id: String = ""
var target_unit_id: String = ""
var target_public_id: String = ""
var target_slot: String = ""

func to_stable_dict() -> Dictionary:
	return {
		"command_id": command_id,
		"turn_index": turn_index,
		"command_type": command_type,
		"command_source": command_source,
		"side_id": side_id,
		"actor_id": actor_id,
		"actor_public_id": actor_public_id,
		"skill_id": skill_id,
		"target_unit_id": target_unit_id,
		"target_public_id": target_public_id,
		"target_slot": target_slot,
	}
