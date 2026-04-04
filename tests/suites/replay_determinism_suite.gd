extends RefCounted
class_name ReplayDeterminismSuite

const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandScript := preload("res://src/battle_core/contracts/command.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("deterministic_replay", failures, Callable(self, "_test_deterministic_replay").bind(harness))
	runner.run_test("replay_runs_to_end", failures, Callable(self, "_test_replay_runs_to_end").bind(harness))
	runner.run_test("miss_path", failures, Callable(self, "_test_miss_path").bind(harness))
	runner.run_test("replay_turn_index_lookup_contract", failures, Callable(self, "_test_replay_turn_index_lookup_contract").bind(harness))

func _test_deterministic_replay(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = sample_factory.build_demo_replay_input(core.service("command_builder"))
	if replay_input == null:
		return harness.fail_result("demo replay input build failed")
	var replay_output_a = core.service("replay_runner").run_replay(replay_input)
	var replay_output_b = core.service("replay_runner").run_replay(replay_input)
	if replay_output_a == null or replay_output_b == null:
		return harness.fail_result("replay output is null")
	if not replay_output_a.succeeded or not replay_output_b.succeeded:
		return harness.fail_result("replay runner returned failed status")
	if replay_output_a.final_state_hash.is_empty() or replay_output_b.final_state_hash.is_empty():
		return harness.fail_result("final_state_hash is empty")
	if replay_output_a.final_state_hash != replay_output_b.final_state_hash:
		return harness.fail_result("final_state_hash mismatch")
	if replay_output_a.event_log.size() != replay_output_b.event_log.size():
		return harness.fail_result("event_log size mismatch")
	return harness.pass_result()

func _test_replay_runs_to_end(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 15
	replay_input.content_snapshot_paths = sample_factory.content_snapshot_paths()
	replay_input.battle_setup = sample_factory.build_sample_setup()
	replay_input.command_stream = [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_strike"}),
	]
	var replay_output = core.service("replay_runner").run_replay(replay_input)
	if replay_output == null or not replay_output.succeeded:
		return harness.fail_result("replay did not complete successfully")
	if replay_output.battle_result == null or not replay_output.battle_result.finished:
		return harness.fail_result("replay battle_result not finished")
	for ev in replay_output.event_log:
		if ev.event_type == EventTypesScript.RESULT_BATTLE_END:
			return harness.pass_result()
	return harness.fail_result("result:battle_end event missing in replay")

func _test_miss_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 5
	replay_input.content_snapshot_paths = sample_factory.content_snapshot_paths()
	replay_input.battle_setup = sample_factory.build_sample_setup()
	replay_input.command_stream = [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_whiff"}),
	]
	var replay_output = core.service("replay_runner").run_replay(replay_input)
	if replay_output == null:
		return harness.fail_result("replay output is null")
	for log_event in replay_output.event_log:
		if log_event.event_type == EventTypesScript.ACTION_MISS:
			return harness.pass_result()
	return harness.fail_result("miss event missing")

func _test_replay_turn_index_lookup_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var command_builder = core.service("command_builder")
	var turn_1_p1 = command_builder.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_field_call"})
	var turn_2_p1 = command_builder.build_command({"turn_index": 2, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"})
	var turn_1_p2 = command_builder.build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_strike"})
	var turn_2_p2 = command_builder.build_command({"turn_index": 2, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_whiff"})
	var mixed_input = _build_replay_input(sample_factory, [turn_2_p1, turn_1_p1, turn_2_p2, turn_1_p2])
	var normalized_input = _build_replay_input(sample_factory, [turn_1_p1, turn_1_p2, turn_2_p1, turn_2_p2])
	var mixed_output = core.service("replay_runner").run_replay(mixed_input)
	var normalized_output = core.service("replay_runner").run_replay(normalized_input)
	if mixed_output == null or normalized_output == null or not mixed_output.succeeded or not normalized_output.succeeded:
		return harness.fail_result("mixed-order replay inputs should still complete successfully")
	if mixed_output.final_state_hash != normalized_output.final_state_hash:
		return harness.fail_result("turn-index grouping must preserve the legacy replay final_state_hash")
	if _stable_log_array(mixed_output.event_log) != _stable_log_array(normalized_output.event_log):
		return harness.fail_result("turn-index grouping must preserve the legacy replay event log")
	return harness.pass_result()

func _build_replay_input(sample_factory, command_stream: Array) -> ReplayInputScript:
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 17
	replay_input.content_snapshot_paths = sample_factory.content_snapshot_paths()
	replay_input.battle_setup = sample_factory.build_sample_setup()
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
