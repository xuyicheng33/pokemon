extends RefCounted
class_name ActionGuardSuite

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("action_effects_on_kill_dispatch", failures, Callable(self, "_test_action_effects_on_kill_dispatch").bind(harness))
    runner.run_test("invalid_command_payload_hard_failures", failures, Callable(self, "_test_invalid_command_payload_hard_failures").bind(harness))
    runner.run_test("invalid_command_payload_out_of_legal_set", failures, Callable(self, "_test_invalid_command_payload_out_of_legal_set").bind(harness))
    runner.run_test("action_failed_post_start_target_missing", failures, Callable(self, "_test_action_failed_post_start_target_missing").bind(harness))
    runner.run_test("invalid_chain_depth_max_guard", failures, Callable(self, "_test_invalid_chain_depth_max_guard").bind(harness))
    runner.run_test("invalid_chain_depth_dedupe_guard", failures, Callable(self, "_test_invalid_chain_depth_dedupe_guard").bind(harness))
    runner.run_test("invalid_state_corruption_guard", failures, Callable(self, "_test_invalid_state_corruption_guard").bind(harness))
    runner.run_test("missing_chain_context_hard_fail", failures, Callable(self, "_test_missing_chain_context_hard_fail").bind(harness))
    runner.run_test("missing_core_dependency_hard_fail", failures, Callable(self, "_test_missing_core_dependency_hard_fail").bind(harness))
    runner.run_test("double_faint_reason_preserved", failures, Callable(self, "_test_double_faint_reason_preserved").bind(harness))
    runner.run_test("battle_end_system_chain", failures, Callable(self, "_test_battle_end_system_chain").bind(harness))

func _test_action_effects_on_kill_dispatch(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var kill_effect_payload = StatModPayloadScript.new()
    kill_effect_payload.payload_type = "stat_mod"
    kill_effect_payload.stat_name = "attack"
    kill_effect_payload.stage_delta = 1
    var kill_effect = EffectDefinitionScript.new()
    kill_effect.id = "test_action_kill_effect"
    kill_effect.display_name = "Action Kill Effect"
    kill_effect.scope = "self"
    kill_effect.trigger_names = PackedStringArray(["on_kill"])
    kill_effect.payloads.clear()
    kill_effect.payloads.append(kill_effect_payload)
    content_index.register_resource(kill_effect)

    var kill_skill = SkillDefinitionScript.new()
    kill_skill.id = "test_action_kill_skill"
    kill_skill.display_name = "Action Kill Skill"
    kill_skill.damage_kind = "physical"
    kill_skill.power = 40
    kill_skill.accuracy = 100
    kill_skill.mp_cost = 0
    kill_skill.priority = 0
    kill_skill.targeting = "enemy_active_slot"
    kill_skill.effects_on_kill_ids = PackedStringArray([kill_effect.id])
    content_index.register_resource(kill_skill)
    if not content_index.units["sample_pyron"].skill_ids.has(kill_skill.id):
        content_index.units["sample_pyron"].skill_ids.append(kill_skill.id)

    var kill_state = harness.build_initialized_battle(core, content_index, sample_factory, 109)
    var kill_p1_active = kill_state.get_side("P1").get_active_unit()
    kill_p1_active.base_speed = 999
    var kill_p2_active = kill_state.get_side("P2").get_active_unit()
    kill_p2_active.current_hp = 1
    core.turn_loop_controller.run_turn(kill_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": kill_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    var has_kill_effect_log: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.target_instance_id == kill_p1_active.unit_instance_id and str(ev.source_instance_id).begins_with("action_"):
            has_kill_effect_log = true
            break
    if not has_kill_effect_log:
        return harness.fail_result("effects_on_kill did not trigger on kill")

    var non_kill_state = harness.build_initialized_battle(core, content_index, sample_factory, 110)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(non_kill_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": kill_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("action_"):
            return harness.fail_result("effects_on_kill should not trigger without kill")
    return harness.pass_result()

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
    core.turn_loop_controller.run_turn(unknown_side_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(duplicate_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "target_public_id": "P1-B",
        }),
        core.command_builder.build_command({
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(non_participant_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-B",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
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

    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_ultimate_burst",
        }),
        core.command_builder.build_command({
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

func _test_action_failed_post_start_target_missing(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 114)

    var actor = battle_state.get_unit_by_public_id("P1-A")
    if actor == null:
        return harness.fail_result("missing P1-A actor")
    var command = core.command_builder.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_id": actor.unit_instance_id,
        "skill_id": "sample_strike",
    })
    var queued_action = core.action_queue_builder.build_queue([command], battle_state, content_index)[0]
    var p2_side = battle_state.get_side("P2")
    p2_side.clear_active_unit()

    var action_result = core.action_executor.execute_action(queued_action, battle_state, content_index)
    if action_result.invalid_battle_code != null:
        return harness.fail_result("target missing at execution start should not raise invalid_battle")
    if action_result.result_type != "action_failed_post_start":
        return harness.fail_result("expected action_failed_post_start when target slot missing, got %s" % str(action_result.result_type))
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.ACTION_FAILED_POST_START:
            return harness.pass_result()
    return harness.fail_result("missing action_failed_post_start log event")

func _test_invalid_chain_depth_max_guard(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 118)

    var depth_guard_payload = StatModPayloadScript.new()
    depth_guard_payload.payload_type = "stat_mod"
    depth_guard_payload.stat_name = "attack"
    depth_guard_payload.stage_delta = 1
    var depth_guard_effect = EffectDefinitionScript.new()
    depth_guard_effect.id = "test_depth_guard_effect"
    depth_guard_effect.display_name = "Depth Guard Effect"
    depth_guard_effect.scope = "self"
    depth_guard_effect.trigger_names = PackedStringArray(["on_cast"])
    depth_guard_effect.payloads.clear()
    depth_guard_effect.payloads.append(depth_guard_payload)
    content_index.register_resource(depth_guard_effect)

    var p1_active = battle_state.get_side("P1").get_active_unit()
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = "test_depth_chain"
    chain_context.chain_origin = "action"
    chain_context.command_type = CommandTypesScript.SKILL
    chain_context.command_source = "manual"
    chain_context.actor_id = p1_active.unit_instance_id
    chain_context.chain_depth = battle_state.max_chain_depth
    battle_state.chain_context = chain_context
    var effect_events = core.trigger_dispatcher.collect_events(
        "on_cast",
        battle_state,
        content_index,
        PackedStringArray([depth_guard_effect.id]),
        p1_active.unit_instance_id,
        "action_depth_guard",
        2,
        p1_active.base_speed,
        battle_state.chain_context
    )
    if effect_events.is_empty():
        return harness.fail_result("failed to build depth guard effect event")
    core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
    if core.payload_executor.last_invalid_battle_code != ErrorCodesScript.INVALID_CHAIN_DEPTH:
        return harness.fail_result("expected invalid_chain_depth on max depth guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
    return harness.pass_result()

func _test_invalid_chain_depth_dedupe_guard(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 119)

    var dedupe_effect = EffectDefinitionScript.new()
    dedupe_effect.id = "test_dedupe_guard_effect"
    dedupe_effect.display_name = "Dedupe Guard Effect"
    dedupe_effect.scope = "self"
    dedupe_effect.trigger_names = PackedStringArray(["on_cast"])
    dedupe_effect.payloads.clear()
    content_index.register_resource(dedupe_effect)

    var p1_active = battle_state.get_side("P1").get_active_unit()
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = "test_dedupe_chain"
    chain_context.chain_origin = "action"
    chain_context.command_type = CommandTypesScript.SKILL
    chain_context.command_source = "manual"
    chain_context.actor_id = p1_active.unit_instance_id
    chain_context.step_counter = 7
    battle_state.chain_context = chain_context
    var effect_events = core.trigger_dispatcher.collect_events(
        "on_cast",
        battle_state,
        content_index,
        PackedStringArray([dedupe_effect.id]),
        p1_active.unit_instance_id,
        "action_dedupe_guard",
        2,
        p1_active.base_speed,
        battle_state.chain_context
    )
    if effect_events.is_empty():
        return harness.fail_result("failed to build dedupe guard effect event")
    core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
    if core.payload_executor.last_invalid_battle_code != null:
        return harness.fail_result("first dedupe event should pass")
    battle_state.chain_context.step_counter = 7
    core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
    if core.payload_executor.last_invalid_battle_code != ErrorCodesScript.INVALID_CHAIN_DEPTH:
        return harness.fail_result("expected invalid_chain_depth on dedupe guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
    return harness.pass_result()

func _test_invalid_state_corruption_guard(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 120)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    p1_active.current_hp = p1_active.max_hp + 1
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if not battle_state.battle_result.finished:
        return harness.fail_result("state corruption should fail-fast")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
        return harness.fail_result("expected invalid_state_corruption, got %s" % str(battle_state.battle_result.reason))
    return harness.pass_result()

func _test_missing_chain_context_hard_fail(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 222)
    battle_state.chain_context = null

    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if not battle_state.battle_result.finished:
        return harness.fail_result("missing chain_context should fail-fast")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
        return harness.fail_result("missing chain_context should map to invalid_state_corruption")
    for ev in core.battle_logger.event_log:
        if String(ev.event_chain_id) == "system:orphan":
            return harness.fail_result("system:orphan fallback should not exist")
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
            return harness.pass_result()
    return harness.fail_result("missing invalid_battle log for missing chain_context")

func _test_missing_core_dependency_hard_fail(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 223)
    core.turn_resolution_service.effect_instance_dispatcher = null

    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if not battle_state.battle_result.finished:
        return harness.fail_result("missing core dependency should fail-fast")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
        return harness.fail_result("missing dependency should map to invalid_state_corruption")
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
            return harness.pass_result()
    return harness.fail_result("missing invalid_battle log for dependency hard-fail")

func _test_double_faint_reason_preserved(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 219)
    for side_state in battle_state.sides:
        for unit_state in side_state.team_units:
            unit_state.current_hp = 0
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if not battle_state.battle_result.finished:
        return harness.fail_result("battle should finish when both sides have no available units")
    if battle_state.battle_result.result_type != "draw":
        return harness.fail_result("double faint should end in draw")
    if battle_state.battle_result.reason != "double_faint":
        return harness.fail_result("double faint reason should remain double_faint, got %s" % str(battle_state.battle_result.reason))
    return harness.pass_result()

func _test_battle_end_system_chain(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var turn_start_battle = harness.build_initialized_battle(core, content_index, sample_factory, 261)
    var turn_start_side = turn_start_battle.get_side("P2")
    if turn_start_side == null:
        return harness.fail_result("turn_start side missing")
    for unit_state in turn_start_side.team_units:
        unit_state.current_hp = 0
    core.turn_loop_controller.run_turn(turn_start_battle, content_index, [])
    var turn_start_battle_end = harness.find_last_event(core.battle_logger.event_log, EventTypesScript.RESULT_BATTLE_END)
    if turn_start_battle_end == null:
        return harness.fail_result("turn_start battle_end event missing")
    if turn_start_battle_end.command_type != EventTypesScript.SYSTEM_TURN_START:
        return harness.fail_result("turn_start battle_end should inherit system:turn_start")
    if turn_start_battle_end.chain_origin != "turn_start":
        return harness.fail_result("turn_start battle_end chain_origin should be turn_start")

    var turn_limit_battle = harness.build_initialized_battle(core, content_index, sample_factory, 262)
    turn_limit_battle.max_turn = 1
    core.turn_loop_controller.run_turn(turn_limit_battle, content_index, [])
    var turn_limit_event = harness.find_last_event(core.battle_logger.event_log, EventTypesScript.SYSTEM_TURN_LIMIT)
    if turn_limit_event == null:
        return harness.fail_result("turn_limit event missing")
    if turn_limit_event.chain_origin != "turn_end":
        return harness.fail_result("turn_limit chain_origin should be turn_end")
    var turn_limit_battle_end = harness.find_last_event(core.battle_logger.event_log, EventTypesScript.RESULT_BATTLE_END)
    if turn_limit_battle_end == null:
        return harness.fail_result("turn_limit battle_end event missing")
    if turn_limit_battle_end.command_type != EventTypesScript.SYSTEM_TURN_LIMIT:
        return harness.fail_result("turn_limit battle_end should inherit system:turn_limit")
    if turn_limit_battle_end.chain_origin != "turn_end":
        return harness.fail_result("turn_limit battle_end chain_origin should be turn_end")
    return harness.pass_result()
