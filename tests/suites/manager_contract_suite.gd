extends RefCounted
class_name ManagerContractSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("full_open_public_snapshot_contract", failures, Callable(self, "_test_full_open_public_snapshot_contract").bind(harness))
    runner.run_test("manager_session_isolation_interleaved_turns", failures, Callable(self, "_test_manager_session_isolation_interleaved_turns").bind(harness))
    runner.run_test("session_seed_and_replay_hash_isolation", failures, Callable(self, "_test_session_seed_and_replay_hash_isolation").bind(harness))
    runner.run_test("replay_isolation_no_session_side_effect", failures, Callable(self, "_test_replay_isolation_no_session_side_effect").bind(harness))
    runner.run_test("replay_snapshot_contract", failures, Callable(self, "_test_replay_snapshot_contract").bind(harness))
    runner.run_test("log_v3_header_contract", failures, Callable(self, "_test_log_v3_header_contract").bind(harness))
    runner.run_test("header_snapshot_private_id_guard", failures, Callable(self, "_test_header_snapshot_private_id_guard").bind(harness))

func _test_full_open_public_snapshot_contract(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var init_result = manager.create_session({
        "battle_seed": 301,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_sample_setup(),
    })
    if init_result == null:
        return harness.fail_result("manager create_session returned null")
    var session_id: String = str(init_result.get("session_id", ""))
    if session_id.is_empty():
        return harness.fail_result("manager create_session missing session_id")
    var public_snapshot = init_result.get("public_snapshot", null)
    if typeof(public_snapshot) != TYPE_DICTIONARY:
        return harness.fail_result("manager create_session missing public_snapshot")
    if not public_snapshot.has("visibility_mode") or str(public_snapshot["visibility_mode"]) != "prototype_full_open":
        return harness.fail_result("public_snapshot visibility_mode should be prototype_full_open")
    if not public_snapshot.has("field") or typeof(public_snapshot["field"]) != TYPE_DICTIONARY:
        return harness.fail_result("public_snapshot should include field snapshot")
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

    var prebattle_public_teams = init_result.get("prebattle_public_teams", null)
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
    var snapshot_after_init = manager.get_public_snapshot(session_id)
    if snapshot_after_init.get("prebattle_public_teams", []).size() != 2:
        return harness.fail_result("get_public_snapshot should keep prebattle_public_teams")
    if _contains_key_recursive(public_snapshot, "unit_instance_id"):
        return harness.fail_result("public_snapshot leaks unit_instance_id")
    if _contains_key_recursive(prebattle_public_teams, "unit_instance_id"):
        return harness.fail_result("prebattle_public_teams leaks unit_instance_id")
    manager.close_session(session_id)
    return harness.pass_result()

func _test_manager_session_isolation_interleaved_turns(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var init_a = manager.create_session({
        "battle_seed": 401,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_sample_setup(),
    })
    var init_b = manager.create_session({
        "battle_seed": 402,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_sample_setup(),
    })
    var session_a: String = str(init_a.get("session_id", ""))
    var session_b: String = str(init_b.get("session_id", ""))
    if session_a == session_b or session_a.is_empty() or session_b.is_empty():
        return harness.fail_result("sessions should be unique")

    var commands_a: Array = [
        manager.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        manager.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    manager.run_turn(session_a, commands_a)
    var snapshot_b_before = manager.get_public_snapshot(session_b)
    if snapshot_b_before != init_b.get("public_snapshot", {}):
        return harness.fail_result("session B should not change after session A run_turn")

    var commands_b: Array = [
        manager.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_field_call",
        }),
        manager.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    manager.run_turn(session_b, commands_b)
    var snapshot_a_after = manager.get_public_snapshot(session_a)
    var snapshot_b_after = manager.get_public_snapshot(session_b)
    if int(snapshot_a_after.get("turn_index", 0)) != 2:
        return harness.fail_result("session A turn index should be 2 after one turn")
    if int(snapshot_b_after.get("turn_index", 0)) != 2:
        return harness.fail_result("session B turn index should be 2 after one turn")
    if snapshot_a_after.get("battle_id", "") == snapshot_b_after.get("battle_id", ""):
        return harness.fail_result("public snapshot battle_id should be isolated by session")
    return harness.pass_result()

func _test_session_seed_and_replay_hash_isolation(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var replay_input_a = sample_factory.build_demo_replay_input(manager)
    replay_input_a.battle_seed = 777
    var replay_a1: Dictionary = manager.run_replay(replay_input_a)
    var replay_a2: Dictionary = manager.run_replay(replay_input_a)
    var output_a1 = replay_a1.get("replay_output", null)
    var output_a2 = replay_a2.get("replay_output", null)
    if output_a1 == null or output_a2 == null or not output_a1.succeeded or not output_a2.succeeded:
        return harness.fail_result("same-seed replay should succeed")
    if output_a1.final_state_hash != output_a2.final_state_hash:
        return harness.fail_result("same-seed replay hash should be stable")
    if output_a1.event_log.size() != output_a2.event_log.size():
        return harness.fail_result("same-seed replay log size should be stable")

    var replay_input_b = sample_factory.build_demo_replay_input(manager)
    replay_input_b.battle_seed = 778
    var replay_b: Dictionary = manager.run_replay(replay_input_b)
    var output_b = replay_b.get("replay_output", null)
    if output_b == null or not output_b.succeeded:
        return harness.fail_result("different-seed replay should succeed")
    if output_a1.final_state_hash == output_b.final_state_hash:
        return harness.fail_result("different seeds should produce isolated final_state_hash")
    return harness.pass_result()

func _test_replay_isolation_no_session_side_effect(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var init_result = manager.create_session({
        "battle_seed": 403,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_sample_setup(),
    })
    var session_id: String = str(init_result.get("session_id", ""))
    if session_id != "session_1":
        return harness.fail_result("first session id should be session_1")
    var snapshot_before_replay = manager.get_public_snapshot(session_id)
    var replay_result = manager.run_replay(sample_factory.build_demo_replay_input(manager))
    if replay_result.get("replay_output", null) == null:
        return harness.fail_result("run_replay should return replay_output")
    var snapshot_after_replay = manager.get_public_snapshot(session_id)
    if snapshot_before_replay != snapshot_after_replay:
        return harness.fail_result("run_replay should not mutate existing sessions")
    var second_session = manager.create_session({
        "battle_seed": 404,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_sample_setup(),
    })
    if str(second_session.get("session_id", "")) != "session_2":
        return harness.fail_result("run_replay should not allocate from active session pool")
    if manager.active_session_count() != 2:
        return harness.fail_result("active session count should remain isolated from replay")
    return harness.pass_result()

func _test_replay_snapshot_contract(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var live_result = manager.create_session({
        "battle_seed": 405,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_sample_setup(),
    })
    var live_snapshot = live_result.get("public_snapshot", {})
    var replay_result: Dictionary = manager.run_replay(sample_factory.build_demo_replay_input(manager))
    var replay_snapshot = replay_result.get("public_snapshot", {})
    if typeof(replay_snapshot) != TYPE_DICTIONARY:
        return harness.fail_result("run_replay should expose public_snapshot")
    if not replay_snapshot.has("prebattle_public_teams"):
        return harness.fail_result("replay public_snapshot missing prebattle_public_teams")
    var shape_error = _validate_snapshot_shape(replay_snapshot)
    if not shape_error.is_empty():
        return harness.fail_result("replay snapshot shape invalid: %s" % shape_error)
    var live_shape_error = _validate_snapshot_shape(live_snapshot)
    if not live_shape_error.is_empty():
        return harness.fail_result("live snapshot shape invalid: %s" % live_shape_error)
    if replay_snapshot.get("visibility_mode", "") != live_snapshot.get("visibility_mode", ""):
        return harness.fail_result("replay snapshot visibility_mode should match live contract")
    return harness.pass_result()

func _test_log_v3_header_contract(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var replay_result: Dictionary = manager.run_replay(sample_factory.build_demo_replay_input(manager))
    var replay_output = replay_result.get("replay_output", null)
    if replay_output == null:
        return harness.fail_result("run_replay should return replay_output")
    var header_count: int = 0
    var header_index: int = -1
    var first_enter_index: int = -1
    for i in range(replay_output.event_log.size()):
        var ev = replay_output.event_log[i]
        if int(ev.log_schema_version) != 3:
            return harness.fail_result("log_schema_version should be 3 for all events")
        if ev.event_type == EventTypesScript.SYSTEM_BATTLE_HEADER:
            header_count += 1
            header_index = i
        if first_enter_index == -1 and ev.event_type == EventTypesScript.STATE_ENTER:
            first_enter_index = i
    if header_count != 1:
        return harness.fail_result("system:battle_header should appear exactly once")
    if first_enter_index == -1:
        return harness.fail_result("state:enter should exist")
    if not (header_index < first_enter_index):
        return harness.fail_result("system:battle_header must be earlier than first state:enter")
    return harness.pass_result()

func _test_header_snapshot_private_id_guard(harness) -> Dictionary:
    var manager_payload = harness.build_manager()
    if manager_payload.has("error"):
        return harness.fail_result(str(manager_payload["error"]))
    var manager = manager_payload["manager"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var replay_result: Dictionary = manager.run_replay(sample_factory.build_demo_replay_input(manager))
    var replay_output = replay_result.get("replay_output", null)
    if replay_output == null:
        return harness.fail_result("run_replay should return replay_output")
    var header_event = null
    for ev in replay_output.event_log:
        if ev.event_type == EventTypesScript.SYSTEM_BATTLE_HEADER:
            header_event = ev
            break
    if header_event == null:
        return harness.fail_result("missing system:battle_header event")
    var header_snapshot = header_event.header_snapshot
    if typeof(header_snapshot) != TYPE_DICTIONARY:
        return harness.fail_result("header_snapshot should be Dictionary")
    var required_fields: Array[String] = [
        "visibility_mode",
        "prebattle_public_teams",
        "initial_active_public_ids_by_side",
        "initial_field",
    ]
    for field_name in required_fields:
        if not header_snapshot.has(field_name):
            return harness.fail_result("header_snapshot missing required field: %s" % field_name)
    if _contains_private_instance_id_key(header_snapshot):
        return harness.fail_result("header_snapshot should not contain private instance IDs")
    return harness.pass_result()

func _validate_snapshot_shape(public_snapshot: Dictionary) -> String:
    if typeof(public_snapshot.get("sides", null)) != TYPE_ARRAY:
        return "missing sides"
    if typeof(public_snapshot.get("field", null)) != TYPE_DICTIONARY:
        return "missing field"
    if typeof(public_snapshot.get("prebattle_public_teams", null)) != TYPE_ARRAY:
        return "missing prebattle_public_teams"
    for side_snapshot in public_snapshot["sides"]:
        if typeof(side_snapshot) != TYPE_DICTIONARY:
            return "side snapshot must be Dictionary"
        if typeof(side_snapshot.get("team_units", null)) != TYPE_ARRAY:
            return "side snapshot missing team_units"
        for unit_snapshot in side_snapshot["team_units"]:
            if typeof(unit_snapshot) != TYPE_DICTIONARY:
                return "team unit snapshot must be Dictionary"
            if typeof(unit_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
                return "team unit snapshot missing combat_type_ids"
    for side_snapshot in public_snapshot["prebattle_public_teams"]:
        if typeof(side_snapshot) != TYPE_DICTIONARY:
            return "prebattle side snapshot must be Dictionary"
        if typeof(side_snapshot.get("units", null)) != TYPE_ARRAY:
            return "prebattle side snapshot missing units"
        for unit_snapshot in side_snapshot["units"]:
            if typeof(unit_snapshot) != TYPE_DICTIONARY:
                return "prebattle unit snapshot must be Dictionary"
            if typeof(unit_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
                return "prebattle unit snapshot missing combat_type_ids"
    return ""

func _contains_key_recursive(value, expected_key: String) -> bool:
    if typeof(value) == TYPE_DICTIONARY:
        for key in value.keys():
            if str(key) == expected_key:
                return true
            if _contains_key_recursive(value[key], expected_key):
                return true
    elif typeof(value) == TYPE_ARRAY:
        for element in value:
            if _contains_key_recursive(element, expected_key):
                return true
    return false

func _contains_private_instance_id_key(value) -> bool:
    if typeof(value) == TYPE_DICTIONARY:
        for key in value.keys():
            var key_text := String(key)
            if key_text == "unit_instance_id" or key_text.ends_with("_instance_id"):
                return true
            if _contains_private_instance_id_key(value[key]):
                return true
    elif typeof(value) == TYPE_ARRAY:
        for element in value:
            if _contains_private_instance_id_key(element):
                return true
    return false
