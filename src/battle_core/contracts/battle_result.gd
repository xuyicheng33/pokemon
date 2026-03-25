extends RefCounted
class_name BattleResult

var finished: bool = false
var winner_side_id: Variant = null
var result_type: String = ""
var reason: String = ""

func to_stable_dict() -> Dictionary:
    return {
        "finished": finished,
        "winner_side_id": winner_side_id,
        "result_type": result_type,
        "reason": reason,
    }
