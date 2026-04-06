extends RefCounted

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("event_log_snapshot_public_contract", failures, Callable(self, "_test_event_log_snapshot_public_contract").bind(harness))
	runner.run_test("event_log_snapshot_readonly_detached_contract", failures, Callable(self, "_test_event_log_snapshot_readonly_detached_contract").bind(harness))

func _test_event_log_snapshot_public_contract(harness) -> Dictionary:
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
	var battle_setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result("gojo_vs_sukuna")
	if not bool(battle_setup_result.get("ok", false)):
		return harness.fail_result("failed to build gojo_vs_sukuna setup: %s" % String(battle_setup_result.get("error_message", "unknown error")))
	var init_result = manager.create_session({
		"battle_seed": 304,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": battle_setup_result.get("data", null),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id: String = str(init_unwrap.get("data", {}).get("session_id", ""))
	var initial_snapshot_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(initial_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(initial_snapshot_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var initial_snapshot: Dictionary = initial_snapshot_unwrap.get("data", {})
	var initial_events: Array = initial_snapshot.get("events", [])
	var initial_total_size: int = int(initial_snapshot.get("total_size", -1))
	if initial_total_size != initial_events.size():
		return harness.fail_result("get_event_log_snapshot total_size should match full snapshot size")
	var turn_result_envelope: Dictionary = manager.run_turn(session_id, [
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "gojo_ao",
		}),
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sukuna_kai",
		}),
	])
	var turn_result_unwrap = _helper.unwrap_ok(turn_result_envelope, "run_turn")
	if not bool(turn_result_unwrap.get("ok", false)):
		return harness.fail_result(str(turn_result_unwrap.get("error", "manager run_turn failed")))
	var turn_result: Dictionary = turn_result_unwrap.get("data", {})
	if typeof(turn_result.get("public_snapshot", null)) != TYPE_DICTIONARY:
		return harness.fail_result("run_turn should keep returning public_snapshot after event log API addition")
	var delta_snapshot_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id, initial_total_size), "get_event_log_snapshot")
	if not bool(delta_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(delta_snapshot_unwrap.get("error", "manager get_event_log_snapshot delta failed")))
	var delta_snapshot: Dictionary = delta_snapshot_unwrap.get("data", {})
	var delta_events: Array = delta_snapshot.get("events", [])
	if delta_events.is_empty():
		return harness.fail_result("event log delta should include turn events after run_turn")
	var action_cast_event_found := false
	var public_value_change_shape_checked := false
	for event_snapshot in delta_events:
		if typeof(event_snapshot) != TYPE_DICTIONARY:
			return harness.fail_result("event log snapshot entries must be Dictionary")
		if _helper.contains_any_key_recursive(event_snapshot, PackedStringArray([
			"actor_id",
			"source_instance_id",
			"target_instance_id",
			"killer_id",
			"entity_id",
		])):
			return harness.fail_result("public event log snapshot must not leak runtime ids")
		if event_snapshot.has("actor_public_id") and event_snapshot.has("actor_definition_id") and event_snapshot.has("target_public_id") and event_snapshot.has("target_definition_id") and event_snapshot.has("killer_public_id") and event_snapshot.has("killer_definition_id"):
			if typeof(event_snapshot.get("value_changes", null)) != TYPE_ARRAY:
				return harness.fail_result("public event log snapshot should keep value_changes as Array")
			for value_change in event_snapshot.get("value_changes", []):
				if typeof(value_change) != TYPE_DICTIONARY:
					return harness.fail_result("public event value_change must be Dictionary")
				if not value_change.has("entity_public_id") or not value_change.has("entity_definition_id"):
					return harness.fail_result("public event value_changes should expose only public-safe entity ids")
			public_value_change_shape_checked = true
		if String(event_snapshot.get("event_type", "")) == EventTypesScript.ACTION_CAST \
		and str(event_snapshot.get("actor_public_id", "")) == "P1-A" \
		and str(event_snapshot.get("actor_definition_id", "")) == "gojo_satoru":
			action_cast_event_found = true
	if not action_cast_event_found:
		return harness.fail_result("event log snapshot should expose derived actor_public_id and actor_definition_id")
	if not public_value_change_shape_checked:
		return harness.fail_result("event log snapshot should expose public-safe value_change entity identifiers")
	var empty_delta_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id, int(delta_snapshot.get("total_size", 0))), "get_event_log_snapshot")
	if not bool(empty_delta_unwrap.get("ok", false)):
		return harness.fail_result(str(empty_delta_unwrap.get("error", "manager get_event_log_snapshot tail failed")))
	var empty_delta: Dictionary = empty_delta_unwrap.get("data", {})
	if not empty_delta.get("events", []).is_empty():
		return harness.fail_result("event log snapshot tail query should return empty delta")
	var close_result = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_result.get("ok", false)):
		return harness.fail_result(str(close_result.get("error", "manager close_session failed")))
	return harness.pass_result()

func _test_event_log_snapshot_readonly_detached_contract(harness) -> Dictionary:
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
		"battle_seed": 3041,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": sample_factory.build_sample_setup(),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var initial_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(initial_log_unwrap.get("ok", false)):
		return harness.fail_result(str(initial_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var initial_events: Array = initial_log_unwrap.get("data", {}).get("events", [])
	var header_event := _find_header_event_snapshot(initial_events)
	if header_event.is_empty():
		return harness.fail_result("event_log snapshot should expose system:battle_header")
	var header_snapshot: Dictionary = header_event.get("header_snapshot", {})
	var original_visibility_mode := String(header_snapshot.get("visibility_mode", ""))
	var header_prebattle_teams: Array = header_snapshot.get("prebattle_public_teams", [])
	if header_prebattle_teams.is_empty():
		return harness.fail_result("header_snapshot should expose prebattle_public_teams")
	var header_skill_ids: PackedStringArray = header_prebattle_teams[0].get("units", [])[0].get("skill_ids", PackedStringArray())
	var original_skill_ids: PackedStringArray = header_skill_ids.duplicate()
	header_snapshot["visibility_mode"] = "mutated_visibility"
	header_skill_ids[0] = "mutated_skill"
	var fresh_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(fresh_log_unwrap.get("ok", false)):
		return harness.fail_result(str(fresh_log_unwrap.get("error", "manager get_event_log_snapshot fresh failed")))
	var fresh_header_event := _find_header_event_snapshot(fresh_log_unwrap.get("data", {}).get("events", []))
	if fresh_header_event.is_empty():
		return harness.fail_result("fresh event_log snapshot should keep system:battle_header")
	var fresh_header_snapshot: Dictionary = fresh_header_event.get("header_snapshot", {})
	var fresh_skill_ids: PackedStringArray = fresh_header_snapshot.get("prebattle_public_teams", [])[0].get("units", [])[0].get("skill_ids", PackedStringArray())
	if String(fresh_header_snapshot.get("visibility_mode", "")) != original_visibility_mode:
		return harness.fail_result("mutating public event header_snapshot should not affect later reads")
	if fresh_skill_ids != original_skill_ids:
		return harness.fail_result("mutating public event prebattle skill_ids should not affect later reads")
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()

func _find_header_event_snapshot(events: Array) -> Dictionary:
	for event_snapshot in events:
		if String(event_snapshot.get("event_type", "")) == EventTypesScript.SYSTEM_BATTLE_HEADER:
			return event_snapshot
	return {}
