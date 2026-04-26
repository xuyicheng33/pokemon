extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func test_action_failed_post_start_target_missing() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 114)
	var actor = battle_state.get_unit_by_public_id("P1-A")
	if actor == null:
		fail("missing P1-A actor")
		return
	var command = core.service("command_builder").build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_id": actor.unit_instance_id,
		"skill_id": "sample_strike",
	})
	var queued_action = core.service("action_queue_builder").build_queue([command], battle_state, content_index)[0]
	var p2_side = battle_state.get_side("P2")
	p2_side.clear_active_unit()
	var action_result = core.service("action_executor").execute_action(queued_action, battle_state, content_index)
	if action_result.invalid_battle_code != null:
		fail("target missing at execution start should not raise invalid_battle")
		return
	if action_result.result_type != "action_failed_post_start":
		fail("expected action_failed_post_start when target slot missing, got %s" % str(action_result.result_type))
		return
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.ACTION_FAILED_POST_START:
			return
	fail("missing action_failed_post_start log event")

func test_double_faint_reason_preserved() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 219)
	for side_state in battle_state.sides:
		for unit_state in side_state.team_units:
			unit_state.current_hp = 0
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		fail("battle should finish when both sides have no available units")
		return
	if battle_state.battle_result.result_type != "draw":
		fail("double faint should end in draw")
		return
	if battle_state.battle_result.reason != "double_faint":
		fail("double faint reason should remain double_faint, got %s" % str(battle_state.battle_result.reason))
		return

func test_battle_end_system_chain() -> void:
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
	var turn_start_battle = _harness.build_initialized_battle(core, content_index, sample_factory, 261)
	var turn_start_side = turn_start_battle.get_side("P2")
	if turn_start_side == null:
		fail("turn_start side missing")
		return
	for unit_state in turn_start_side.team_units:
		unit_state.current_hp = 0
	core.service("turn_loop_controller").run_turn(turn_start_battle, content_index, [])
	var turn_start_battle_end = _harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.RESULT_BATTLE_END)
	if turn_start_battle_end == null:
		fail("turn_start battle_end event missing")
		return
	if turn_start_battle_end.command_type != EventTypesScript.SYSTEM_TURN_START:
		fail("turn_start battle_end should inherit system:turn_start")
		return
	if turn_start_battle_end.chain_origin != "turn_start":
		fail("turn_start battle_end chain_origin should be turn_start")
		return
	var turn_limit_battle = _harness.build_initialized_battle(core, content_index, sample_factory, 262)
	turn_limit_battle.max_turn = 1
	core.service("turn_loop_controller").run_turn(turn_limit_battle, content_index, [])
	var turn_limit_event = _harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.SYSTEM_TURN_LIMIT)
	if turn_limit_event == null:
		fail("turn_limit event missing")
		return
	if turn_limit_event.chain_origin != "turn_end":
		fail("turn_limit chain_origin should be turn_end")
		return
	var turn_limit_battle_end = _harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.RESULT_BATTLE_END)
	if turn_limit_battle_end == null:
		fail("turn_limit battle_end event missing")
		return
	if turn_limit_battle_end.command_type != EventTypesScript.SYSTEM_TURN_LIMIT:
		fail("turn_limit battle_end should inherit system:turn_limit")
		return
	if turn_limit_battle_end.chain_origin != "turn_end":
		fail("turn_limit battle_end chain_origin should be turn_end")
		return
	var execution_battle = _harness.build_initialized_battle(core, content_index, sample_factory, 263)
	var execution_p1_active = execution_battle.get_side("P1").get_active_unit()
	var execution_p2_side = execution_battle.get_side("P2")
	if execution_p1_active == null or execution_p2_side == null:
		fail("execution battle setup missing active units")
		return
	for unit_state in execution_p2_side.team_units:
		unit_state.current_hp = 0
	var execution_p2_active = execution_p2_side.get_active_unit()
	if execution_p2_active == null:
		fail("execution battle missing target active unit")
		return
	execution_p2_active.current_hp = 1
	execution_p1_active.base_speed = 999
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(execution_battle, content_index, [
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
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var execution_battle_end = _harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.RESULT_BATTLE_END)
	if execution_battle_end == null:
		fail("execution battle_end event missing")
		return
	if execution_battle_end.command_type != CommandTypesScript.SKILL:
		fail("execution battle_end should inherit root action command_type")
		return
	if execution_battle_end.chain_origin != "action":
		fail("execution battle_end chain_origin should stay action")
		return
	if String(execution_battle_end.actor_id) != String(execution_p1_active.unit_instance_id):
		fail("execution battle_end should inherit root action actor_id")
		return

