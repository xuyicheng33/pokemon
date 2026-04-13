extends "res://test/suites/manager_snapshot_public_contract/base.gd"
const BaseSuiteScript := preload("res://test/suites/manager_snapshot_public_contract/base.gd")



func test_full_open_public_snapshot_contract() -> void:
	_assert_legacy_result(_test_full_open_public_snapshot_contract(_harness))

func test_public_snapshot_readonly_detached_contract() -> void:
	_assert_legacy_result(_test_public_snapshot_readonly_detached_contract(_harness))
func _test_full_open_public_snapshot_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var init_result = manager.create_session({
		"battle_seed": 301,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": harness.build_sample_setup(sample_factory),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var init_data: Dictionary = init_unwrap.get("data", {})
	var session_id: String = str(init_data.get("session_id", ""))
	if session_id.is_empty():
		return harness.fail_result("manager create_session missing session_id")
	var public_snapshot = init_data.get("public_snapshot", null)
	if typeof(public_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("manager create_session missing public_snapshot")
	if not public_snapshot.has("visibility_mode") or str(public_snapshot["visibility_mode"]) != "prototype_full_open":
		return harness.fail_result("public_snapshot visibility_mode should be prototype_full_open")
	if not public_snapshot.has("field") or typeof(public_snapshot["field"]) != TYPE_DICTIONARY:
		return harness.fail_result("public_snapshot should include field snapshot")
	var field_snapshot: Dictionary = public_snapshot["field"]
	if not field_snapshot.has("field_kind") or not field_snapshot.has("creator_side_id"):
		return harness.fail_result("field snapshot should expose field_kind and creator_side_id")
	if not public_snapshot.has("sides") or public_snapshot["sides"].size() != 2:
		return harness.fail_result("public_snapshot should include 2 sides")
	for side_snapshot in public_snapshot["sides"]:
		if typeof(side_snapshot) != TYPE_DICTIONARY:
			return harness.fail_result("side snapshot should be Dictionary")
		if not side_snapshot.has("active_public_id") or not side_snapshot.has("active_hp") or not side_snapshot.has("active_mp"):
			return harness.fail_result("legacy active fields missing in side snapshot")
		if not side_snapshot.has("bench_public_ids") or not side_snapshot.has("team_units"):
			return harness.fail_result("side snapshot missing bench/team fields")
		if side_snapshot["team_units"].size() != 3:
			return harness.fail_result("team_units should include 3 entries per side")
		for unit_snapshot in side_snapshot["team_units"]:
			if typeof(unit_snapshot) != TYPE_DICTIONARY:
				return harness.fail_result("team unit snapshot should be Dictionary")
			if typeof(unit_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
				return harness.fail_result("team unit snapshot missing combat_type_ids")
	var prebattle_public_teams = init_data.get("prebattle_public_teams", null)
	if typeof(prebattle_public_teams) != TYPE_ARRAY or prebattle_public_teams.size() != 2:
		return harness.fail_result("create_session should expose prebattle_public_teams")
	if prebattle_public_teams != public_snapshot.get("prebattle_public_teams", []):
		return harness.fail_result("prebattle_public_teams should equal snapshot payload")
	var p1_prebattle_units: Array = prebattle_public_teams[0].get("units", [])
	if p1_prebattle_units.is_empty():
		return harness.fail_result("prebattle_public_teams should include unit payloads")
	var p1_lead_snapshot = p1_prebattle_units[0]
	if typeof(p1_lead_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
		return harness.fail_result("prebattle unit snapshot missing combat_type_ids")
	if p1_lead_snapshot["combat_type_ids"] != PackedStringArray(["fire"]):
		return harness.fail_result("prebattle unit combat_type_ids should expose sample fire typing")
	var snapshot_after_init_result = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(snapshot_after_init_result.get("ok", false)):
		return harness.fail_result(str(snapshot_after_init_result.get("error", "manager get_public_snapshot failed")))
	var snapshot_after_init: Dictionary = snapshot_after_init_result.get("data", {})
	if snapshot_after_init.get("prebattle_public_teams", []).size() != 2:
		return harness.fail_result("get_public_snapshot should keep prebattle_public_teams")
	if _helper.contains_key_recursive(public_snapshot, "unit_instance_id"):
		return harness.fail_result("public_snapshot leaks unit_instance_id")
	if _helper.contains_key_recursive(prebattle_public_teams, "unit_instance_id"):
		return harness.fail_result("prebattle_public_teams leaks unit_instance_id")
	var close_result = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_result.get("ok", false)):
		return harness.fail_result(str(close_result.get("error", "manager close_session failed")))
	return harness.pass_result()

func _test_public_snapshot_readonly_detached_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 3011,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": harness.build_sample_setup(sample_factory),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var init_data: Dictionary = init_unwrap.get("data", {})
	var session_id := String(init_data.get("session_id", ""))
	var public_snapshot: Dictionary = init_data.get("public_snapshot", {})
	var create_prebattle_teams: Array = init_data.get("prebattle_public_teams", [])
	if create_prebattle_teams.is_empty():
		return harness.fail_result("create_session should expose prebattle_public_teams")
	var public_prebattle_teams: Array = public_snapshot.get("prebattle_public_teams", [])
	if public_prebattle_teams.is_empty():
		return harness.fail_result("public_snapshot should expose prebattle_public_teams")
	var create_p1_prebattle_units: Array = create_prebattle_teams[0].get("units", [])
	var public_p1_prebattle_units: Array = public_prebattle_teams[0].get("units", [])
	var public_side_units: Array = public_snapshot.get("sides", [])[0].get("team_units", [])
	var create_prebattle_skill_ids: PackedStringArray = create_p1_prebattle_units[0].get("skill_ids", PackedStringArray())
	var public_prebattle_skill_ids: PackedStringArray = public_p1_prebattle_units[0].get("skill_ids", PackedStringArray())
	var public_combat_type_ids: PackedStringArray = public_side_units[0].get("combat_type_ids", PackedStringArray())
	var original_public_skill_ids: PackedStringArray = public_prebattle_skill_ids.duplicate()
	var original_public_types: PackedStringArray = public_combat_type_ids.duplicate()
	create_prebattle_skill_ids[0] = "top_level_mutation"
	if public_prebattle_skill_ids != original_public_skill_ids:
		return harness.fail_result("create_session top-level prebattle_public_teams should not alias public_snapshot payload")
	public_prebattle_skill_ids[0] = "snapshot_mutation"
	public_combat_type_ids[0] = "mutated_type"
	var fresh_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(fresh_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(fresh_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var fresh_snapshot: Dictionary = fresh_snapshot_unwrap.get("data", {})
	var fresh_prebattle_teams: Array = fresh_snapshot.get("prebattle_public_teams", [])
	if fresh_prebattle_teams.is_empty():
		return harness.fail_result("fresh public_snapshot should keep prebattle_public_teams")
	var fresh_skill_ids: PackedStringArray = fresh_prebattle_teams[0].get("units", [])[0].get("skill_ids", PackedStringArray())
	var fresh_combat_type_ids: PackedStringArray = fresh_snapshot.get("sides", [])[0].get("team_units", [])[0].get("combat_type_ids", PackedStringArray())
	if fresh_skill_ids != original_public_skill_ids:
		return harness.fail_result("mutating public snapshot skill_ids should not affect later reads")
	if fresh_combat_type_ids != original_public_types:
		return harness.fail_result("mutating public snapshot combat_type_ids should not affect later reads")
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()
