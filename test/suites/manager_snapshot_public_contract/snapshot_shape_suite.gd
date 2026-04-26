extends "res://test/suites/manager_snapshot_public_contract/base.gd"

func test_full_open_public_snapshot_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var init_result = manager.create_session({
		"battle_seed": 301,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": _harness.build_sample_setup(sample_factory),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var init_data: Dictionary = init_unwrap.get("data", {})
	var session_id: String = str(init_data.get("session_id", ""))
	if session_id.is_empty():
		fail("manager create_session missing session_id")
		return
	var public_snapshot = init_data.get("public_snapshot", null)
	if typeof(public_snapshot) != TYPE_DICTIONARY:
		fail("manager create_session missing public_snapshot")
		return
	if not public_snapshot.has("visibility_mode") or str(public_snapshot["visibility_mode"]) != "prototype_full_open":
		fail("public_snapshot visibility_mode should be prototype_full_open")
		return
	if not public_snapshot.has("field") or typeof(public_snapshot["field"]) != TYPE_DICTIONARY:
		fail("public_snapshot should include field snapshot")
		return
	var field_snapshot: Dictionary = public_snapshot["field"]
	if not field_snapshot.has("field_kind") or not field_snapshot.has("creator_side_id"):
		fail("field snapshot should expose field_kind and creator_side_id")
		return
	if not public_snapshot.has("sides") or public_snapshot["sides"].size() != 2:
		fail("public_snapshot should include 2 sides")
		return
	for side_snapshot in public_snapshot["sides"]:
		if typeof(side_snapshot) != TYPE_DICTIONARY:
			fail("side snapshot should be Dictionary")
			return
		if not side_snapshot.has("active_public_id") or not side_snapshot.has("active_hp") or not side_snapshot.has("active_mp"):
			fail("legacy active fields missing in side snapshot")
			return
		if not side_snapshot.has("bench_public_ids") or not side_snapshot.has("team_units"):
			fail("side snapshot missing bench/team fields")
			return
		if side_snapshot["team_units"].size() != 3:
			fail("team_units should include 3 entries per side")
			return
		for unit_snapshot in side_snapshot["team_units"]:
			if typeof(unit_snapshot) != TYPE_DICTIONARY:
				fail("team unit snapshot should be Dictionary")
				return
			if typeof(unit_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
				fail("team unit snapshot missing combat_type_ids")
				return
	var prebattle_public_teams = init_data.get("prebattle_public_teams", null)
	if typeof(prebattle_public_teams) != TYPE_ARRAY or prebattle_public_teams.size() != 2:
		fail("create_session should expose prebattle_public_teams")
		return
	if prebattle_public_teams != public_snapshot.get("prebattle_public_teams", []):
		fail("prebattle_public_teams should equal snapshot payload")
		return
	var p1_prebattle_units: Array = prebattle_public_teams[0].get("units", [])
	if p1_prebattle_units.is_empty():
		fail("prebattle_public_teams should include unit payloads")
		return
	var p1_lead_snapshot = p1_prebattle_units[0]
	if typeof(p1_lead_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
		fail("prebattle unit snapshot missing combat_type_ids")
		return
	if p1_lead_snapshot["combat_type_ids"] != PackedStringArray(["fire"]):
		fail("prebattle unit combat_type_ids should expose sample fire typing")
		return
	var snapshot_after_init_result = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(snapshot_after_init_result.get("ok", false)):
		fail(str(snapshot_after_init_result.get("error", "manager get_public_snapshot failed")))
		return
	var snapshot_after_init: Dictionary = snapshot_after_init_result.get("data", {})
	if snapshot_after_init.get("prebattle_public_teams", []).size() != 2:
		fail("get_public_snapshot should keep prebattle_public_teams")
		return
	if _helper.contains_key_recursive(public_snapshot, "unit_instance_id"):
		fail("public_snapshot leaks unit_instance_id")
		return
	if _helper.contains_key_recursive(prebattle_public_teams, "unit_instance_id"):
		fail("prebattle_public_teams leaks unit_instance_id")
		return
	var close_result = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_result.get("ok", false)):
		fail(str(close_result.get("error", "manager close_session failed")))
		return

func test_public_snapshot_readonly_detached_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 3011,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": _harness.build_sample_setup(sample_factory),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var init_data: Dictionary = init_unwrap.get("data", {})
	var session_id := String(init_data.get("session_id", ""))
	var public_snapshot: Dictionary = init_data.get("public_snapshot", {})
	var create_prebattle_teams: Array = init_data.get("prebattle_public_teams", [])
	if create_prebattle_teams.is_empty():
		fail("create_session should expose prebattle_public_teams")
		return
	var public_prebattle_teams: Array = public_snapshot.get("prebattle_public_teams", [])
	if public_prebattle_teams.is_empty():
		fail("public_snapshot should expose prebattle_public_teams")
		return
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
		fail("create_session top-level prebattle_public_teams should not alias public_snapshot payload")
		return
	public_prebattle_skill_ids[0] = "snapshot_mutation"
	public_combat_type_ids[0] = "mutated_type"
	var fresh_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(fresh_snapshot_unwrap.get("ok", false)):
		fail(str(fresh_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
		return
	var fresh_snapshot: Dictionary = fresh_snapshot_unwrap.get("data", {})
	var fresh_prebattle_teams: Array = fresh_snapshot.get("prebattle_public_teams", [])
	if fresh_prebattle_teams.is_empty():
		fail("fresh public_snapshot should keep prebattle_public_teams")
		return
	var fresh_skill_ids: PackedStringArray = fresh_prebattle_teams[0].get("units", [])[0].get("skill_ids", PackedStringArray())
	var fresh_combat_type_ids: PackedStringArray = fresh_snapshot.get("sides", [])[0].get("team_units", [])[0].get("combat_type_ids", PackedStringArray())
	if fresh_skill_ids != original_public_skill_ids:
		fail("mutating public snapshot skill_ids should not affect later reads")
		return
	if fresh_combat_type_ids != original_public_types:
		fail("mutating public snapshot combat_type_ids should not affect later reads")
		return
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		fail(str(close_unwrap.get("error", "manager close_session failed")))
		return

