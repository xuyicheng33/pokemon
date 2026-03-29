extends RefCounted
class_name QueuedAction

var action_id: String = ""
var queue_index: int = -1
var command = null
var actor_snapshot_id: String = ""
var target_snapshot = null
var priority: int = 0
var speed_snapshot: int = 0
var speed_tie_roll: Variant = null
var domain_clash_protected: bool = false

func to_stable_dict() -> Dictionary:
    return {
        "action_id": action_id,
        "queue_index": queue_index,
        "command": command.to_stable_dict() if command != null else null,
        "actor_snapshot_id": actor_snapshot_id,
        "target_snapshot": target_snapshot.to_stable_dict() if target_snapshot != null else null,
        "priority": priority,
        "speed_snapshot": speed_snapshot,
        "speed_tie_roll": speed_tie_roll,
        "domain_clash_protected": domain_clash_protected,
    }
