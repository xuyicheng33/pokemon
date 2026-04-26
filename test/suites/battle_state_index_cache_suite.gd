extends "res://tests/support/gdunit_suite_bridge.gd"

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const SideStateScript := preload("res://src/battle_core/runtime/side_state.gd")
const UnitStateScript := preload("res://src/battle_core/runtime/unit_state.gd")

func test_append_side_reflects_live_lookup_contract() -> void:
	var battle_state = BattleStateScript.new()
	var side_state = _build_side("P1", [_build_unit("unit_p1_a", "P1-A")])
	battle_state.append_side(side_state)
	if battle_state.get_side("P1") != side_state:
		fail("append_side should expose side_id immediately")
		return
	if battle_state.get_unit("unit_p1_a") != side_state.team_units[0]:
		fail("append_side should expose unit_instance_id immediately")
		return
	if battle_state.get_unit_by_public_id("P1-A") != side_state.team_units[0]:
		fail("append_side should expose public_id immediately")
		return

func test_direct_side_array_replacement_updates_live_lookup() -> void:
	var battle_state = BattleStateScript.new()
	var original_side = _build_side("P1", [_build_unit("unit_p1_a", "P1-A")])
	var replacement_side = _build_side("P2", [_build_unit("unit_p2_a", "P2-A")])
	battle_state.append_side(original_side)
	if battle_state.get_side("P1") != original_side:
		fail("precondition failed: original side should be readable")
		return
	battle_state.sides = [replacement_side]
	if battle_state.get_side("P1") != null:
		fail("get_side should not return stale side after sides array replacement")
		return
	if battle_state.get_side("P2") != replacement_side:
		fail("get_side should reflect sides array replacement immediately")
		return
	if battle_state.get_unit("unit_p2_a") != replacement_side.team_units[0]:
		fail("get_unit should reflect sides array replacement immediately")
		return
	if battle_state.get_unit_by_public_id("P2-A") != replacement_side.team_units[0]:
		fail("get_unit_by_public_id should reflect sides array replacement immediately")
		return

func test_direct_team_unit_mutation_updates_live_lookup() -> void:
	var battle_state = BattleStateScript.new()
	var side_state = _build_side("P1", [_build_unit("unit_p1_a", "P1-A")])
	var replacement_unit = _build_unit("unit_p1_b", "P1-B")
	battle_state.append_side(side_state)
	if battle_state.get_unit("unit_p1_a") != side_state.team_units[0]:
		fail("precondition failed: original unit should be readable")
		return
	side_state.team_units = [replacement_unit]
	if battle_state.get_unit("unit_p1_a") != null:
		fail("get_unit should not return stale unit after direct team_units replacement")
		return
	if battle_state.get_unit("unit_p1_b") != replacement_unit:
		fail("get_unit should reflect direct team_units replacement immediately")
		return
	if battle_state.get_unit_by_public_id("P1-B") != replacement_unit:
		fail("get_unit_by_public_id should reflect direct team_units replacement immediately")
		return
	if battle_state.get_unit_by_public_id("P1-A") != null:
		fail("get_unit_by_public_id should clear stale public_id after direct team_units replacement")
		return


func _build_side(side_id: String, team_units: Array) -> Variant:
	var side_state = SideStateScript.new()
	side_state.side_id = side_id
	side_state.team_units = team_units
	if not team_units.is_empty():
		side_state.active_slots["active_0"] = team_units[0].unit_instance_id
	return side_state

func _build_unit(unit_instance_id: String, public_id: String) -> Variant:
	var unit_state = UnitStateScript.new()
	unit_state.unit_instance_id = unit_instance_id
	unit_state.public_id = public_id
	unit_state.display_name = public_id
	return unit_state
