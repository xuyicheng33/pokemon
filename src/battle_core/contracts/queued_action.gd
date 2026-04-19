extends RefCounted
class_name QueuedAction

var action_id: String = ""
var queue_index: int = -1
var command: Command = null
var actor_snapshot_id: String = ""
var target_snapshot: TargetSnapshot = null
var priority: int = 0
var speed_snapshot: int = 0
var speed_tie_roll: Variant = null
var domain_clash_protected: bool = false
var defer_domain_success_effects: bool = false

func to_stable_dict() -> Dictionary:
	var command_dict: Variant = null
	if command != null:
		command_dict = command.to_stable_dict()
	var target_snapshot_dict: Variant = null
	if target_snapshot != null:
		target_snapshot_dict = target_snapshot.to_stable_dict()
	return {
		"action_id": action_id,
		"queue_index": queue_index,
		"command": command_dict,
		"actor_snapshot_id": actor_snapshot_id,
		"target_snapshot": target_snapshot_dict,
		"priority": priority,
		"speed_snapshot": speed_snapshot,
		"speed_tie_roll": speed_tie_roll,
		"domain_clash_protected": domain_clash_protected,
		"defer_domain_success_effects": defer_domain_success_effects,
	}
