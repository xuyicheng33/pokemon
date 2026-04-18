extends RefCounted
class_name TurnLimitScoringService

func build_scored_sides(battle_state) -> Array:
	var scored_sides: Array = []
	for side_state in battle_state.sides:
		scored_sides.append(_build_side_score(side_state))
	scored_sides.sort_custom(_sort_scores)
	return scored_sides

func scores_tied(scored_sides: Array) -> bool:
	if scored_sides.size() <= 1:
		return false
	return _scores_equal(scored_sides[0], scored_sides[1])

func _build_side_score(side_state) -> Dictionary:
	var available_count: int = 0
	var current_hp_total: int = 0
	var max_hp_total: int = 0
	for unit_state in side_state.team_units:
		if unit_state.current_hp > 0:
			available_count += 1
		current_hp_total += unit_state.current_hp
		max_hp_total += unit_state.max_hp
	return {
		"side_id": side_state.side_id,
		"available_count": available_count,
		"current_hp_total": current_hp_total,
		"max_hp_total": max_hp_total,
	}

func _sort_scores(left: Dictionary, right: Dictionary) -> bool:
	if left["available_count"] != right["available_count"]:
		return left["available_count"] > right["available_count"]
	var left_cross: int = int(left["current_hp_total"]) * int(right["max_hp_total"])
	var right_cross: int = int(right["current_hp_total"]) * int(left["max_hp_total"])
	if left_cross != right_cross:
		return left_cross > right_cross
	if left["current_hp_total"] != right["current_hp_total"]:
		return left["current_hp_total"] > right["current_hp_total"]
	return left["side_id"] < right["side_id"]

func _scores_equal(left: Dictionary, right: Dictionary) -> bool:
	return left["available_count"] == right["available_count"] \
	and left["current_hp_total"] * right["max_hp_total"] == right["current_hp_total"] * left["max_hp_total"] \
	and left["current_hp_total"] == right["current_hp_total"]
