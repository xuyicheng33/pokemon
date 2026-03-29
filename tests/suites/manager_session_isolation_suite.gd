extends RefCounted
class_name ManagerSessionIsolationSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("manager_session_isolation_interleaved_turns", failures, Callable(self, "_test_manager_session_isolation_interleaved_turns").bind(harness))
	runner.run_test("session_seed_and_replay_hash_isolation", failures, Callable(self, "_test_session_seed_and_replay_hash_isolation").bind(harness))
	runner.run_test("replay_isolation_no_session_side_effect", failures, Callable(self, "_test_replay_isolation_no_session_side_effect").bind(harness))

func _test_manager_session_isolation_interleaved_turns(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var init_a = manager.create_session({"battle_seed": 401, "content_snapshot_paths": sample_factory.content_snapshot_paths(), "battle_setup": sample_factory.build_sample_setup()})
	var init_b = manager.create_session({"battle_seed": 402, "content_snapshot_paths": sample_factory.content_snapshot_paths(), "battle_setup": sample_factory.build_sample_setup()})
	var session_a: String = str(init_a.get("session_id", ""))
	var session_b: String = str(init_b.get("session_id", ""))
	if session_a == session_b or session_a.is_empty() or session_b.is_empty():
		return harness.fail_result("sessions should be unique")
	var commands_a: Array = [
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_strike"}),
	]
	manager.run_turn(session_a, commands_a)
	var snapshot_b_before = manager.get_public_snapshot(session_b)
	if snapshot_b_before != init_b.get("public_snapshot", {}):
		return harness.fail_result("session B should not change after session A run_turn")
	var commands_b: Array = [
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_field_call"}),
		manager.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_whiff"}),
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
	var init_result = manager.create_session({"battle_seed": 403, "content_snapshot_paths": sample_factory.content_snapshot_paths(), "battle_setup": sample_factory.build_sample_setup()})
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
	var second_session = manager.create_session({"battle_seed": 404, "content_snapshot_paths": sample_factory.content_snapshot_paths(), "battle_setup": sample_factory.build_sample_setup()})
	if str(second_session.get("session_id", "")) != "session_2":
		return harness.fail_result("run_replay should not allocate from active session pool")
	if manager.active_session_count() != 2:
		return harness.fail_result("active session count should remain isolated from replay")
	return harness.pass_result()
