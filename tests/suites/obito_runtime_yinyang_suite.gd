extends RefCounted
class_name ObitoRuntimeYinyangSuite

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const QueuedActionScript := preload("res://src/battle_core/contracts/queued_action.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")
const TargetSnapshotScript := preload("res://src/battle_core/contracts/target_snapshot.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("obito_yinyang_dun_cast_contract", failures, Callable(self, "_test_obito_yinyang_dun_cast_contract").bind(harness))
    runner.run_test("obito_yinyang_dun_segment_mitigation_and_stack_contract", failures, Callable(self, "_test_obito_yinyang_dun_segment_mitigation_and_stack_contract").bind(harness))
    runner.run_test("obito_yinyang_dun_non_skill_segment_ignored_contract", failures, Callable(self, "_test_obito_yinyang_dun_non_skill_segment_ignored_contract").bind(harness))
    runner.run_test("obito_yinyang_dun_same_side_segment_ignored_contract", failures, Callable(self, "_test_obito_yinyang_dun_same_side_segment_ignored_contract").bind(harness))
    runner.run_test("obito_yinyang_dun_stack_cap_contract", failures, Callable(self, "_test_obito_yinyang_dun_stack_cap_contract").bind(harness))

func _test_obito_yinyang_dun_cast_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), 1520)
    var obito = battle_state.get_side("P1").get_active_unit()
    if obito == null:
        return harness.fail_result("missing obito active unit for yinyang cast contract")
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _support.count_effect_instances(obito, "obito_yinyang_zhili") != 1:
        return harness.fail_result("obito_yinyang_dun should grant one stack immediately")
    if int(obito.get_effective_stage("defense")) != 1 or int(obito.get_effective_stage("sp_defense")) != 1:
        return harness.fail_result("obito_yinyang_dun should grant defense +1 and sp_defense +1")
    return harness.pass_result()

func _test_obito_yinyang_dun_segment_mitigation_and_stack_contract(harness) -> Dictionary:
    var baseline_result = _run_yinyang_guard_case(harness, false, 1521, 0)
    if not bool(baseline_result.get("ok", false)):
        return harness.fail_result(str(baseline_result.get("error", "baseline yinyang guard case failed")))
    var guarded_result = _run_yinyang_guard_case(harness, true, 1522, 0)
    if not bool(guarded_result.get("ok", false)):
        return harness.fail_result(str(guarded_result.get("error", "guarded yinyang guard case failed")))
    if int(guarded_result.get("hp_loss", -1)) >= int(baseline_result.get("hp_loss", -1)):
        return harness.fail_result("obito_yinyang_dun should reduce incoming multihit damage")
    if int(guarded_result.get("yinyang_count", -1)) != 3:
        return harness.fail_result("obito_yinyang_dun should leave obito at 3 stacks after cast + 2 received segments")
    return harness.pass_result()

func _test_obito_yinyang_dun_stack_cap_contract(harness) -> Dictionary:
    var capped_result = _run_yinyang_guard_case(harness, true, 1523, 5)
    if not bool(capped_result.get("ok", false)):
        return harness.fail_result(str(capped_result.get("error", "capped yinyang guard case failed")))
    if int(capped_result.get("yinyang_count", -1)) != 5:
        return harness.fail_result("obito_yinyang_dun should respect the 5-stack cap during multihit guard")
    if int(capped_result.get("defense_stage", -1)) != 1 or int(capped_result.get("sp_defense_stage", -1)) != 1:
        return harness.fail_result("obito_yinyang_dun should still grant stat stages even when yinyang stacks are capped")
    return harness.pass_result()

func _test_obito_yinyang_dun_non_skill_segment_ignored_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), 1524)
    var obito = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if obito == null or target == null:
        return harness.fail_result("missing active units for obito non-skill segment contract")
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var baseline_count := _support.count_effect_instances(obito, "obito_yinyang_zhili")
    if baseline_count != 1:
        return harness.fail_result("obito_yinyang_dun should seed exactly one initial stack before non-skill trigger probe")
    battle_state.chain_context = _build_non_skill_segment_chain_context(target.unit_instance_id, obito.unit_instance_id)
    var invalid_code = core.service("trigger_batch_runner").execute_trigger_batch(
        "on_receive_action_damage_segment",
        battle_state,
        content_index,
        [obito.unit_instance_id],
        battle_state.chain_context
    )
    if invalid_code != null:
        return harness.fail_result("non-skill segment trigger probe should not invalidate battle: %s" % str(invalid_code))
    if _support.count_effect_instances(obito, "obito_yinyang_zhili") != baseline_count:
        return harness.fail_result("obito_yinyang_dun should ignore non-skill damage segment triggers")
    return harness.pass_result()

func _test_obito_yinyang_dun_same_side_segment_ignored_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), 1525)
    var obito_side = battle_state.get_side("P1")
    var obito = obito_side.get_active_unit() if obito_side != null else null
    if obito == null or obito_side == null or obito_side.team_units.size() < 2:
        return harness.fail_result("missing obito side context for same-side segment contract")
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var baseline_count := _support.count_effect_instances(obito, "obito_yinyang_zhili")
    if baseline_count != 1:
        return harness.fail_result("obito_yinyang_dun should seed exactly one initial stack before same-side trigger probe")
    var ally = obito_side.team_units[1]
    var queued_action = QueuedActionScript.new()
    queued_action.command = _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_qiudao_jiaotu")
    queued_action.command.actor_id = obito.unit_instance_id
    queued_action.target_snapshot = TargetSnapshotScript.new()
    queued_action.target_snapshot.target_kind = "enemy_active_slot"
    queued_action.target_snapshot.target_unit_id = ally.unit_instance_id
    battle_state.chain_context = _build_non_skill_segment_chain_context(obito.unit_instance_id, obito.unit_instance_id)
    var segment_context_service = core.service("action_cast_direct_damage_pipeline")._segment_trigger_context_service
    var invalid_code = segment_context_service.execute_receive_damage_segment_trigger(
        queued_action,
        battle_state,
        content_index,
        ally.unit_instance_id,
        1,
        1,
        "fire",
        core.service("trigger_batch_runner")
    )
    if invalid_code != null:
        return harness.fail_result("same-side segment trigger probe should not invalidate battle: %s" % str(invalid_code))
    if _support.count_effect_instances(obito, "obito_yinyang_zhili") != baseline_count:
        return harness.fail_result("obito_yinyang_dun should ignore same-side damage segment triggers")
    return harness.pass_result()

func _run_yinyang_guard_case(harness, use_guard: bool, seed: int, preseed_stacks: int) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return {"ok": false, "error": str(core_payload["error"])}
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return {"ok": false, "error": "SampleBattleFactory init failed"}
    var content_index = harness.build_loaded_content_index(sample_factory)
    var skill = _build_enemy_multihit_skill("test_obito_yinyang_multihit_skill")
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), seed)
    var obito = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if obito == null or target == null:
        return {"ok": false, "error": "missing active units for obito yinyang guard case"}
    var yinyang_definition = content_index.effects.get("obito_yinyang_zhili", null)
    if yinyang_definition == null:
        return {"ok": false, "error": "missing obito_yinyang_zhili definition"}
    for _i in range(preseed_stacks):
        if core.service("effect_instance_service").create_instance(yinyang_definition, obito.unit_instance_id, battle_state, "test_preseed_yinyang", 2, obito.base_speed) == null:
            return {"ok": false, "error": "failed to preseed yinyang stack"}
    var before_hp := int(obito.current_hp)
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun") if use_guard else _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-A", skill.id),
    ])
    return {
        "ok": true,
        "hp_loss": before_hp - int(obito.current_hp),
        "yinyang_count": _support.count_effect_instances(obito, "obito_yinyang_zhili"),
        "defense_stage": int(obito.get_effective_stage("defense")),
        "sp_defense_stage": int(obito.get_effective_stage("sp_defense")),
    }

func _build_enemy_multihit_skill(skill_id: String):
    var skill = SkillDefinitionScript.new()
    skill.id = skill_id
    skill.display_name = skill_id
    skill.damage_kind = "special"
    skill.power = 20
    skill.accuracy = 100
    skill.mp_cost = 0
    skill.priority = 0
    skill.combat_type_id = ""
    skill.targeting = "enemy_active_slot"
    var segment = SkillDamageSegmentScript.new()
    segment.repeat_count = 2
    segment.power = 20
    segment.combat_type_id = "fire"
    segment.damage_kind = "special"
    skill.damage_segments.append(segment)
    return skill

func _build_non_skill_segment_chain_context(actor_id: String, target_unit_id: String):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = "test_obito_non_skill_segment"
    chain_context.chain_origin = "action"
    chain_context.command_type = "switch"
    chain_context.command_source = "manual"
    chain_context.actor_id = actor_id
    chain_context.action_actor_id = actor_id
    chain_context.target_unit_id = target_unit_id
    chain_context.action_combat_type_id = "fire"
    chain_context.action_segment_index = 1
    chain_context.action_segment_total = 1
    return chain_context
