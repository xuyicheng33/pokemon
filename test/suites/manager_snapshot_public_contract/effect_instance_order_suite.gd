extends "res://test/suites/manager_snapshot_public_contract/base.gd"
const BaseSuiteScript := preload("res://test/suites/manager_snapshot_public_contract/base.gd")



func test_public_snapshot_effect_instance_order_contract() -> void:
	_assert_legacy_result(_test_public_snapshot_effect_instance_order_contract())
func _test_public_snapshot_effect_instance_order_contract() -> Dictionary:
	var battle_state = BattleStateScript.new()
	battle_state.battle_id = "snapshot_sort_contract"
	battle_state.turn_index = 3
	battle_state.phase = "selection"
	battle_state.visibility_mode = "prototype_full_open"
	var side_state = SideStateScript.new()
	side_state.side_id = "P1"
	var unit_state = UnitStateScript.new()
	unit_state.unit_instance_id = "unit_p1_a"
	unit_state.public_id = "P1-A"
	unit_state.definition_id = "sample_pyron"
	unit_state.display_name = "Sample Pyron"
	unit_state.max_hp = 100
	unit_state.current_hp = 100
	unit_state.max_mp = 10
	unit_state.current_mp = 10
	unit_state.combat_type_ids = PackedStringArray(["fire"])
	unit_state.effect_instances = [
		_build_public_effect_instance("effect_02", "duplicate_mark", 1, false),
		_build_public_effect_instance("effect_04", "duplicate_mark", 2, true),
		_build_public_effect_instance("effect_01", "duplicate_mark", 1, false),
		_build_public_effect_instance("effect_03", "alpha_mark", 2, false),
	]
	side_state.team_units.append(unit_state)
	side_state.active_slots["active_0"] = unit_state.unit_instance_id
	battle_state.append_side(side_state)
	var builder = PublicSnapshotBuilderScript.new()
	var public_snapshot: Dictionary = builder.build_public_snapshot(battle_state)
	var unit_snapshot := _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if unit_snapshot.is_empty():
		return {"ok": false, "error": "public snapshot should expose the synthetic unit"}
	var effect_instances: Array = unit_snapshot.get("effect_instances", [])
	if effect_instances.size() != 4:
		return {"ok": false, "error": "public snapshot should expose all synthetic effect instances"}
	var actual_rows: Array[String] = []
	for effect_snapshot in effect_instances:
		actual_rows.append("%s|%d|%d" % [
			String(effect_snapshot.get("effect_definition_id", "")),
			int(effect_snapshot.get("remaining", -1)),
			int(bool(effect_snapshot.get("persists_on_switch", false))),
		])
	var expected_rows: Array[String] = [
		"alpha_mark|2|0",
		"duplicate_mark|1|0",
		"duplicate_mark|1|0",
		"duplicate_mark|2|1",
	]
	if actual_rows != expected_rows:
		return {
			"ok": false,
			"error": "public snapshot effect_instances should sort by definition/remaining/persist flag before instance tie-break",
		}
	return {"ok": true}
