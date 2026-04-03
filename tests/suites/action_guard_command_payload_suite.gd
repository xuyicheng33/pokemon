extends RefCounted
class_name ActionGuardCommandPayloadSuite

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("invalid_command_payload_hard_failures", failures, Callable(self, "_test_invalid_command_payload_hard_failures").bind(harness))
	runner.run_test("invalid_command_payload_out_of_legal_set", failures, Callable(self, "_test_invalid_command_payload_out_of_legal_set").bind(harness))

func _test_invalid_command_payload_hard_failures(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var unknown_side_state = harness.build_initialized_battle(core, content_index, sample_factory, 111)
	core.service("turn_loop_controller").run_turn(unknown_side_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P3",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
	])
	if not unknown_side_state.battle_result.finished or unknown_side_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		return harness.fail_result("unknown side command should fail-fast with invalid_command_payload")

	var duplicate_state = harness.build_initialized_battle(core, content_index, sample_factory, 112)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(duplicate_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SWITCH,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"target_public_id": "P1-B",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
	])
	if not duplicate_state.battle_result.finished or duplicate_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		return harness.fail_result("duplicate submit should fail-fast with invalid_command_payload")

	var non_participant_state = harness.build_initialized_battle(core, content_index, sample_factory, 113)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(non_participant_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-B",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
	])
	if not non_participant_state.battle_result.finished or non_participant_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		return harness.fail_result("non-participant actor should fail-fast with invalid_command_payload")
	return harness.pass_result()

func _test_invalid_command_payload_out_of_legal_set(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 214)

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_ultimate_burst",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
	])
	if not battle_state.battle_result.finished:
		return harness.fail_result("illegal skill submit should end battle in selection phase")
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		return harness.fail_result("expected invalid_command_payload, got %s" % str(battle_state.battle_result.reason))
	return harness.pass_result()
