extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")


func test_manager_session_isolation_interleaved_turns() -> void:
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
	var snapshot_paths: PackedStringArray = snapshot_paths_payload.get("paths", PackedStringArray())
	var init_a = manager.create_session({"battle_seed": 401, "content_snapshot_paths": snapshot_paths, "battle_setup": _harness.build_sample_setup(sample_factory)})
	var init_b = manager.create_session({"battle_seed": 402, "content_snapshot_paths": snapshot_paths, "battle_setup": _harness.build_sample_setup(sample_factory)})
	var init_a_unwrap = _unwrap_ok(init_a, "create_session")
	var init_b_unwrap = _unwrap_ok(init_b, "create_session")
	if not bool(init_a_unwrap.get("ok", false)):
		fail(str(init_a_unwrap.get("error", "manager create_session A failed")))
		return
	if not bool(init_b_unwrap.get("ok", false)):
		fail(str(init_b_unwrap.get("error", "manager create_session B failed")))
		return
	var session_a: String = str(init_a_unwrap.get("data", {}).get("session_id", ""))
	var session_b: String = str(init_b_unwrap.get("data", {}).get("session_id", ""))
	if session_a == session_b or session_a.is_empty() or session_b.is_empty():
		fail("sessions should be unique")
		return
	var commands_a: Array = [
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_strike"}),
	]
	var run_a_unwrap = _unwrap_ok(manager.run_turn(session_a, commands_a), "run_turn")
	if not bool(run_a_unwrap.get("ok", false)):
		fail(str(run_a_unwrap.get("error", "manager run_turn A failed")))
		return
	var snapshot_b_before_unwrap = _unwrap_ok(manager.get_public_snapshot(session_b), "get_public_snapshot")
	if not bool(snapshot_b_before_unwrap.get("ok", false)):
		fail(str(snapshot_b_before_unwrap.get("error", "manager get_public_snapshot B failed")))
		return
	var snapshot_b_before = snapshot_b_before_unwrap.get("data", {})
	if snapshot_b_before != init_b_unwrap.get("data", {}).get("public_snapshot", {}):
		fail("session B should not change after session A run_turn")
		return
	var commands_b: Array = [
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_field_call"}),
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_whiff"}),
	]
	var run_b_unwrap = _unwrap_ok(manager.run_turn(session_b, commands_b), "run_turn")
	if not bool(run_b_unwrap.get("ok", false)):
		fail(str(run_b_unwrap.get("error", "manager run_turn B failed")))
		return
	var snapshot_a_after_unwrap = _unwrap_ok(manager.get_public_snapshot(session_a), "get_public_snapshot")
	var snapshot_b_after_unwrap = _unwrap_ok(manager.get_public_snapshot(session_b), "get_public_snapshot")
	if not bool(snapshot_a_after_unwrap.get("ok", false)):
		fail(str(snapshot_a_after_unwrap.get("error", "manager get_public_snapshot A failed")))
		return
	if not bool(snapshot_b_after_unwrap.get("ok", false)):
		fail(str(snapshot_b_after_unwrap.get("error", "manager get_public_snapshot B failed")))
		return
	var snapshot_a_after = snapshot_a_after_unwrap.get("data", {})
	var snapshot_b_after = snapshot_b_after_unwrap.get("data", {})
	if int(snapshot_a_after.get("turn_index", 0)) != 2:
		fail("session A turn index should be 2 after one turn")
		return
	if int(snapshot_b_after.get("turn_index", 0)) != 2:
		fail("session B turn index should be 2 after one turn")
		return
	if snapshot_a_after.get("battle_id", "") == snapshot_b_after.get("battle_id", ""):
		fail("public snapshot battle_id should be isolated by session")
		return

func test_session_seed_and_replay_hash_isolation() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var replay_input_a = _harness.build_demo_replay_input(sample_factory, manager)
	replay_input_a.battle_seed = 777
	var replay_a1_unwrap = _unwrap_ok(manager.run_replay(replay_input_a), "run_replay")
	var replay_a2_unwrap = _unwrap_ok(manager.run_replay(replay_input_a), "run_replay")
	if not bool(replay_a1_unwrap.get("ok", false)):
		fail(str(replay_a1_unwrap.get("error", "run_replay A1 failed")))
		return
	if not bool(replay_a2_unwrap.get("ok", false)):
		fail(str(replay_a2_unwrap.get("error", "run_replay A2 failed")))
		return
	var output_a1 = replay_a1_unwrap.get("data", {}).get("replay_output", null)
	var output_a2 = replay_a2_unwrap.get("data", {}).get("replay_output", null)
	if output_a1 == null or output_a2 == null or not output_a1.succeeded or not output_a2.succeeded:
		fail("same-seed replay should succeed")
		return
	if output_a1.final_state_hash != output_a2.final_state_hash:
		fail("same-seed replay hash should be stable")
		return
	if output_a1.event_log.size() != output_a2.event_log.size():
		fail("same-seed replay log size should be stable")
		return
	var replay_input_b = _harness.build_demo_replay_input(sample_factory, manager)
	replay_input_b.battle_seed = 778
	var replay_b_unwrap = _unwrap_ok(manager.run_replay(replay_input_b), "run_replay")
	if not bool(replay_b_unwrap.get("ok", false)):
		fail(str(replay_b_unwrap.get("error", "run_replay B failed")))
		return
	var output_b = replay_b_unwrap.get("data", {}).get("replay_output", null)
	if output_b == null or not output_b.succeeded:
		fail("different-seed replay should succeed")
		return
	if output_a1.final_state_hash == output_b.final_state_hash:
		fail("different seeds should produce isolated final_state_hash")
		return

func test_replay_isolation_no_session_side_effect() -> void:
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
	var snapshot_paths: PackedStringArray = snapshot_paths_payload.get("paths", PackedStringArray())
	var init_result = manager.create_session({"battle_seed": 403, "content_snapshot_paths": snapshot_paths, "battle_setup": _harness.build_sample_setup(sample_factory)})
	var init_unwrap = _unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var session_id: String = str(init_unwrap.get("data", {}).get("session_id", ""))
	if session_id != "session_1":
		fail("first session id should be session_1")
		return
	var snapshot_before_replay_unwrap = _unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(snapshot_before_replay_unwrap.get("ok", false)):
		fail(str(snapshot_before_replay_unwrap.get("error", "manager get_public_snapshot failed")))
		return
	var snapshot_before_replay = snapshot_before_replay_unwrap.get("data", {})
	var replay_unwrap = _unwrap_ok(manager.run_replay(_harness.build_demo_replay_input(sample_factory, manager)), "run_replay")
	if not bool(replay_unwrap.get("ok", false)):
		fail(str(replay_unwrap.get("error", "run_replay failed")))
		return
	if replay_unwrap.get("data", {}).get("replay_output", null) == null:
		fail("run_replay should return replay_output")
		return
	var snapshot_after_replay_unwrap = _unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(snapshot_after_replay_unwrap.get("ok", false)):
		fail(str(snapshot_after_replay_unwrap.get("error", "manager get_public_snapshot after replay failed")))
		return
	var snapshot_after_replay = snapshot_after_replay_unwrap.get("data", {})
	if snapshot_before_replay != snapshot_after_replay:
		fail("run_replay should not mutate existing sessions")
		return
	var second_session = manager.create_session({"battle_seed": 404, "content_snapshot_paths": snapshot_paths, "battle_setup": _harness.build_sample_setup(sample_factory)})
	var second_session_unwrap = _unwrap_ok(second_session, "create_session")
	if not bool(second_session_unwrap.get("ok", false)):
		fail(str(second_session_unwrap.get("error", "manager second create_session failed")))
		return
	if str(second_session_unwrap.get("data", {}).get("session_id", "")) != "session_2":
		fail("run_replay should not allocate from active session pool")
		return
	var count_unwrap = _unwrap_ok(manager.active_session_count(), "active_session_count")
	if not bool(count_unwrap.get("ok", false)):
		fail(str(count_unwrap.get("error", "manager active_session_count failed")))
		return
	if int(count_unwrap.get("data", {}).get("count", -1)) != 2:
		fail("active session count should remain isolated from replay")
		return


func _unwrap_ok(envelope: Dictionary, label: String) -> Dictionary:
	if envelope == null:
		return {"ok": false, "error": "%s returned null envelope" % label}
	var required_keys := ["ok", "data", "error_code", "error_message"]
	for key in required_keys:
		if not envelope.has(key):
			return {"ok": false, "error": "%s missing envelope key: %s" % [label, key]}
	if bool(envelope.get("ok", false)):
		return {"ok": true, "data": envelope.get("data", null)}
	if envelope.get("data", null) != null:
		return {"ok": false, "error": "%s failure envelope must set data=null" % label}
	return {"ok": false, "error": "%s failed: %s (%s)" % [label, str(envelope.get("error_message", "")), str(envelope.get("error_code", ""))]}
