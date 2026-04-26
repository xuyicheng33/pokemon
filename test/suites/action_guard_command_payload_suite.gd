extends "res://tests/support/gdunit_suite_bridge.gd"

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")


func test_invalid_command_payload_hard_failures() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var unknown_side_state = _harness.build_initialized_battle(core, content_index, sample_factory, 111)
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
		fail("unknown side command should fail-fast with invalid_command_payload")
		return

	var duplicate_state = _harness.build_initialized_battle(core, content_index, sample_factory, 112)
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
		fail("duplicate submit should fail-fast with invalid_command_payload")
		return

	var non_participant_state = _harness.build_initialized_battle(core, content_index, sample_factory, 113)
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
		fail("non-participant actor should fail-fast with invalid_command_payload")
		return

func test_invalid_command_payload_out_of_legal_set() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 214)

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
		fail("illegal skill submit should end battle in selection phase")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		fail("expected invalid_command_payload, got %s" % str(battle_state.battle_result.reason))
		return

func test_surrender_command_payload_still_validates_actor_and_turn() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var stale_turn_state = _harness.build_initialized_battle(core, content_index, sample_factory, 215)
	core.service("turn_loop_controller").run_turn(stale_turn_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SURRENDER,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if not stale_turn_state.battle_result.finished or stale_turn_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		fail("stale-turn surrender should fail-fast with invalid_command_payload")
		return

	var bench_actor_state = _harness.build_initialized_battle(core, content_index, sample_factory, 216)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(bench_actor_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SURRENDER,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-B",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if not bench_actor_state.battle_result.finished or bench_actor_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		fail("bench-actor surrender should fail-fast with invalid_command_payload")
		return

