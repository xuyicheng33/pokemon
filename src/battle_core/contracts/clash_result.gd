extends RefCounted
class_name ClashResult

var challenger_won: bool = false
var same_creator: bool = false
var challenger_creator: String = ""
var incumbent_creator: String = ""
var challenger_mp: int = 0
var incumbent_mp: int = 0
var tie_roll: Variant = null

func to_stable_dict() -> Dictionary:
	return {
		"challenger_won": challenger_won,
		"same_creator": same_creator,
		"challenger_creator": challenger_creator,
		"incumbent_creator": incumbent_creator,
		"challenger_mp": challenger_mp,
		"incumbent_mp": incumbent_mp,
		"tie_roll": tie_roll,
	}
