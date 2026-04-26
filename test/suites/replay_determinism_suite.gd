extends "res://tests/support/gdunit_suite_bridge.gd"

const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandScript := preload("res://src/battle_core/contracts/command.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ReplayRunnerOutputHelperScript := preload("res://src/battle_core/logging/replay_runner_output_helper.gd")


func test_deterministic_replay() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var replay_input = _harness.build_demo_replay_input(sample_factory, core.service("command_builder"))
	if replay_input == null:
		fail("demo replay input build failed")
		return
	var replay_output_a = core.service("replay_runner").run_replay(replay_input)
	var replay_output_b = core.service("replay_runner").run_replay(replay_input)
	if replay_output_a == null or replay_output_b == null:
		fail("replay output is null")
		return
	if not replay_output_a.succeeded or not replay_output_b.succeeded:
		fail("replay runner returned failed status")
		return
	if replay_output_a.final_state_hash.is_empty() or replay_output_b.final_state_hash.is_empty():
		fail("final_state_hash is empty")
		return
	if replay_output_a.final_state_hash != replay_output_b.final_state_hash:
		fail("final_state_hash mismatch")
		return
	if replay_output_a.event_log.size() != replay_output_b.event_log.size():
		fail("event_log size mismatch")
		return

func test_replay_runs_to_end() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 15
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = _harness.build_sample_setup(sample_factory)
	replay_input.command_stream = [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_strike"}),
	]
	var replay_output = core.service("replay_runner").run_replay(replay_input)
	if replay_output == null or not replay_output.succeeded:
		fail("replay did not complete successfully")
		return
	if replay_output.battle_result == null or not replay_output.battle_result.finished:
		fail("replay battle_result not finished")
		return
	for ev in replay_output.event_log:
		if ev.event_type == EventTypesScript.RESULT_BATTLE_END:
			return
	fail("result:battle_end event missing in replay")

func test_miss_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 5
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = _harness.build_sample_setup(sample_factory)
	replay_input.command_stream = [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_whiff"}),
	]
	var replay_output = core.service("replay_runner").run_replay(replay_input)
	if replay_output == null:
		fail("replay output is null")
		return
	for log_event in replay_output.event_log:
		if log_event.event_type == EventTypesScript.ACTION_MISS:
			return
	fail("miss event missing")

func test_replay_turn_index_lookup_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var command_builder = core.service("command_builder")
	var turn_1_p1 = command_builder.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_field_call"})
	var turn_2_p1 = command_builder.build_command({"turn_index": 2, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"})
	var turn_1_p2 = command_builder.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_strike"})
	var turn_2_p2 = command_builder.build_command({"turn_index": 2, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_whiff"})
	var mixed_input = _build_replay_input(_harness, sample_factory, [turn_2_p1, turn_1_p1, turn_2_p2, turn_1_p2])
	var normalized_input = _build_replay_input(_harness, sample_factory, [turn_1_p1, turn_1_p2, turn_2_p1, turn_2_p2])
	var mixed_output = core.service("replay_runner").run_replay(mixed_input)
	var normalized_output = core.service("replay_runner").run_replay(normalized_input)
	if mixed_output == null or normalized_output == null or not mixed_output.succeeded or not normalized_output.succeeded:
		fail("mixed-order replay inputs should still complete successfully")
		return
	if mixed_output.final_state_hash != normalized_output.final_state_hash:
		fail("turn-index grouping must preserve the legacy replay final_state_hash")
		return
	if _stable_log_array(mixed_output.event_log) != _stable_log_array(normalized_output.event_log):
		fail("turn-index grouping must preserve the legacy replay event log")
		return

func test_replay_turn_timeline_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var replay_input = _harness.build_demo_replay_input(sample_factory, core.service("command_builder"))
	if replay_input == null:
		fail("demo replay input build failed")
		return
	var replay_output = core.service("replay_runner").run_replay(replay_input)
	if replay_output == null or not replay_output.succeeded:
		fail("replay runner should return successful replay_output for timeline contract")
		return
	if not (replay_output.turn_timeline is Array) or replay_output.turn_timeline.size() < 2:
		fail("turn_timeline should include initial frame and at least one completed turn frame")
		return
	var initial_frame: Dictionary = replay_output.turn_timeline[0]
	if int(initial_frame.get("turn_index", -1)) != 0:
		fail("initial frame turn_index should be 0")
		return
	if int(initial_frame.get("event_from", -1)) != 0 or int(initial_frame.get("event_to", -1)) != 0:
		fail("initial frame event range should be 0..0")
		return
	if not (initial_frame.get("public_snapshot", null) is Dictionary):
		fail("initial frame should expose public_snapshot")
		return
	var final_frame: Dictionary = replay_output.turn_timeline[replay_output.turn_timeline.size() - 1]
	if int(final_frame.get("event_to", -1)) != replay_output.event_log.size():
		fail("final frame should cover all replay events")
		return
	if not bool(final_frame.get("battle_finished", false)):
		fail("final frame should mark battle_finished=true")
		return
	var final_snapshot: Dictionary = final_frame.get("public_snapshot", {})
	var final_battle_result = final_snapshot.get("battle_result", {})
	if not (final_battle_result is Dictionary) or not bool(final_battle_result.get("finished", false)):
		fail("final frame public_snapshot should expose finished battle_result")
		return

func test_final_state_hash_tracks_once_per_battle_usage_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var battle_setup_result: Dictionary = sample_factory.build_formal_character_setup_result("kashimo_hajime")
	if not bool(battle_setup_result.get("ok", false)):
		fail("failed to build Kashimo setup for final_state_hash contract: %s" % String(battle_setup_result.get("error_message", "unknown error")))
		return
	var battle_setup = battle_setup_result.get("data", null)
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 913, battle_setup)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var opponent = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or opponent == null:
		fail("missing active units for once_per_battle state-hash contract")
		return
	kashimo.current_mp = kashimo.max_mp
	kashimo.ultimate_points = kashimo.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.ULTIMATE,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": kashimo.public_id,
			"skill_id": "kashimo_phantom_beast_amber",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": opponent.public_id,
		}),
	])
	if not kashimo.has_used_once_per_battle_skill("kashimo_phantom_beast_amber"):
		fail("amber cast should write once_per_battle usage before final_state_hash probe")
		return
	var output_helper = ReplayRunnerOutputHelperScript.new()
	var with_usage_hash := String(output_helper.compute_state_hash(battle_state))
	kashimo.used_once_per_battle_skill_ids = PackedStringArray()
	var without_usage_hash := String(output_helper.compute_state_hash(battle_state))
	if with_usage_hash.is_empty() or without_usage_hash.is_empty():
		fail("final_state_hash should not be empty in once_per_battle probe")
		return
	if with_usage_hash == without_usage_hash:
		fail("final_state_hash should change when once_per_battle usage record changes")
		return


func _build_replay_input(harness, sample_factory, command_stream: Array) -> ReplayInputScript:
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 17
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	assert(not snapshot_paths_payload.has("error"), "content snapshot path build failed: %s" % str(snapshot_paths_payload.get("error", "unknown error")))
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = harness.build_sample_setup(sample_factory)
	replay_input.command_stream = []
	for command in command_stream:
		replay_input.command_stream.append(_clone_command(command))
	return replay_input

func _clone_command(command) -> CommandScript:
	var clone = CommandScript.new()
	if command == null:
		return clone
	clone.command_id = String(command.command_id)
	clone.turn_index = int(command.turn_index)
	clone.command_type = String(command.command_type)
	clone.command_source = String(command.command_source)
	clone.side_id = String(command.side_id)
	clone.actor_id = String(command.actor_id)
	clone.actor_public_id = String(command.actor_public_id)
	clone.skill_id = String(command.skill_id)
	clone.target_unit_id = String(command.target_unit_id)
	clone.target_public_id = String(command.target_public_id)
	clone.target_slot = String(command.target_slot)
	return clone

func _stable_log_array(event_log: Array) -> Array:
	var stable_events: Array = []
	for log_event in event_log:
		stable_events.append(log_event.to_stable_dict())
	return stable_events
