extends RefCounted
class_name GojoSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()
func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("gojo_content_and_setup_contract", failures, Callable(self, "_test_gojo_content_and_setup_contract").bind(harness))
    runner.run_test("gojo_first_turn_mp_contract", failures, Callable(self, "_test_gojo_first_turn_mp_contract").bind(harness))
    runner.run_test("gojo_ao_hit_contract", failures, Callable(self, "_test_gojo_ao_hit_contract").bind(harness))
    runner.run_test("gojo_aka_hit_contract", failures, Callable(self, "_test_gojo_aka_hit_contract").bind(harness))
    runner.run_test("gojo_murasaki_no_marks_contract", failures, Callable(self, "_test_gojo_murasaki_no_marks_contract").bind(harness))
    runner.run_test("gojo_murasaki_double_mark_burst_contract", failures, Callable(self, "_test_gojo_murasaki_double_mark_burst_contract").bind(harness))
    runner.run_test("gojo_murasaki_base_kill_contract", failures, Callable(self, "_test_gojo_murasaki_base_kill_contract").bind(harness))
    runner.run_test("gojo_murasaki_burst_kill_contract", failures, Callable(self, "_test_gojo_murasaki_burst_kill_contract").bind(harness))
    runner.run_test("gojo_murasaki_retargeted_switch_contract", failures, Callable(self, "_test_gojo_murasaki_retargeted_switch_contract").bind(harness))
    runner.run_test("gojo_mugen_incoming_accuracy_contract", failures, Callable(self, "_test_gojo_mugen_incoming_accuracy_contract").bind(harness))
    runner.run_test("gojo_mugen_reentry_contract", failures, Callable(self, "_test_gojo_mugen_reentry_contract").bind(harness))
    runner.run_test("gojo_unlimited_void_runtime_contract", failures, Callable(self, "_test_gojo_unlimited_void_runtime_contract").bind(harness))
    runner.run_test("gojo_unlimited_void_cancelled_pre_start_contract", failures, Callable(self, "_test_gojo_unlimited_void_cancelled_pre_start_contract").bind(harness))
    runner.run_test("gojo_reverse_ritual_heal_contract", failures, Callable(self, "_test_gojo_reverse_ritual_heal_contract").bind(harness))
    runner.run_test("gojo_plus5_competition_contract", failures, Callable(self, "_test_gojo_plus5_competition_contract").bind(harness))
    runner.run_test("gojo_marker_switch_lifecycle_contract", failures, Callable(self, "_test_gojo_marker_switch_lifecycle_contract").bind(harness))
    runner.run_test("gojo_marker_refresh_contract", failures, Callable(self, "_test_gojo_marker_refresh_contract").bind(harness))
func _test_gojo_content_and_setup_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var gojo = content_index.units.get("gojo_satoru", null)
    if gojo == null:
        return harness.fail_result("missing gojo unit definition")
    if gojo.skill_ids != PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"]):
        return harness.fail_result("gojo default loadout must stay fixed as 苍/赫/茈")
    if gojo.candidate_skill_ids != PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"]):
        return harness.fail_result("gojo candidate skill pool should stay fixed as 苍/赫/茈/反转术式")
    if gojo.ultimate_skill_id != "gojo_unlimited_void":
        return harness.fail_result("gojo ultimate should stay fixed as 无量空处")
    if gojo.passive_skill_id != "gojo_mugen":
        return harness.fail_result("gojo passive should stay fixed as 无下限")
    var gojo_vs_sukuna = sample_factory.build_gojo_vs_sukuna_setup()
    if gojo_vs_sukuna.sides[0].unit_definition_ids[0] != "gojo_satoru" or gojo_vs_sukuna.sides[1].unit_definition_ids[0] != "sukuna":
        return harness.fail_result("gojo vs sukuna sample setup should place Gojo and Sukuna on active slots")
    var ritual_loadout: PackedStringArray = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
    var gojo_vs_sample = sample_factory.build_gojo_vs_sample_setup({"P1": {0: ritual_loadout}})
    if gojo_vs_sample.sides[0].unit_definition_ids[0] != "gojo_satoru" or gojo_vs_sample.sides[1].unit_definition_ids[0] != "sample_pyron":
        return harness.fail_result("gojo vs sample setup should expose Gojo and sample unit on active slots")
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1201, gojo_vs_sample)
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    if gojo_unit == null or gojo_unit.regular_skill_ids != ritual_loadout:
        return harness.fail_result("gojo runtime loadout should mirror setup override")
    var legal_actions = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not legal_actions.legal_skill_ids.has("gojo_reverse_ritual") or legal_actions.legal_skill_ids.has("gojo_murasaki"):
        return harness.fail_result("gojo setup override should expose 反转术式 and hide 茈")
    return harness.pass_result()
func _test_gojo_first_turn_mp_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1202, sample_factory.build_gojo_vs_sample_setup())
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    if gojo_unit == null:
        return harness.fail_result("missing gojo active unit")
    if gojo_unit.current_mp != 64:
        return harness.fail_result("gojo first actionable turn mp should be 64, got %d" % gojo_unit.current_mp)
    return harness.pass_result()
func _test_gojo_ao_hit_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1203)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_ao"].accuracy = 100
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if int(gojo_unit.stat_stages.get("speed", 0)) != 1:
        return harness.fail_result("苍命中后应给自己 speed +1")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 1:
        return harness.fail_result("苍命中后应给目标挂上苍标记")
    return harness.pass_result()
func _test_gojo_aka_hit_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1204)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_aka"].accuracy = 100
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_aka"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if int(target_unit.stat_stages.get("speed", 0)) != -1:
        return harness.fail_result("赫命中后应给目标 speed -1")
    if _count_effect_instances(target_unit, "gojo_aka_mark") != 1:
        return harness.fail_result("赫命中后应给目标挂上赫标记")
    return harness.pass_result()
func _test_gojo_murasaki_no_marks_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1205)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_murasaki"].accuracy = 100
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 1:
        return harness.fail_result("茈在无双标记时只能命中一次本体伤害")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
        return harness.fail_result("茈在无双标记时不应误清或误造标记")
    return harness.pass_result()
func _test_gojo_murasaki_double_mark_burst_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1206)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_murasaki"].accuracy = 100
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    _apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 2:
        return harness.fail_result("茈在双标记时应追加第二段伤害")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
        return harness.fail_result("茈在双标记追加后应清掉双标记")
    return harness.pass_result()
func _test_gojo_murasaki_base_kill_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1207)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_murasaki"].accuracy = 100
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    target_unit.current_hp = 30
    _apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 1:
        return harness.fail_result("茈本体先击杀时不应再触发追加段")
    return harness.pass_result()
func _test_gojo_murasaki_burst_kill_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1208)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_murasaki"].accuracy = 100
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    target_unit.current_hp = 50
    _apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 2:
        return harness.fail_result("茈追加段击杀时仍应保留第二段伤害结算")
    if _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE
    ):
        return harness.fail_result("茈追加段击杀后清标记应静默跳过，不能报 invalid_battle")
    return harness.pass_result()
func _test_gojo_murasaki_retargeted_switch_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1209)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_murasaki"].accuracy = 100
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var original_target = battle_state.get_side("P2").get_active_unit()
    _apply_gojo_double_marks(core, content_index, battle_state, original_target, gojo_unit.unit_instance_id, gojo_unit.base_speed)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
    ])
    var new_target = battle_state.get_side("P2").get_active_unit()
    if new_target == null or new_target.public_id != "P2-B":
        return harness.fail_result("target switch should complete before priority -1 茈")
    if _count_target_damage_events(core.battle_logger.event_log, new_target.unit_instance_id) != 1:
        return harness.fail_result("原目标先换下时，茈应命中新 active 且只打本体")
    if _count_target_damage_events(core.battle_logger.event_log, original_target.unit_instance_id) != 0:
        return harness.fail_result("原目标离场后不应继续承受茈伤害")
    return harness.pass_result()
func _test_gojo_mugen_incoming_accuracy_contract(harness) -> Dictionary:
    var state_payload = _build_sample_vs_gojo_state(harness, 1210, true)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var attacker = battle_state.get_side("P1").get_active_unit()
    var gojo_unit = battle_state.get_side("P2").get_active_unit()
    if _count_rule_mod_instances(gojo_unit, "incoming_accuracy") != 1:
        return harness.fail_result("gojo active unit should carry one incoming_accuracy rule_mod from 无下限")
    var accuracy_skill = _build_accuracy_skill("test_gojo_mugen_95", 95)
    var command = _build_resolved_skill_command(core, 1, "P1", attacker.public_id, attacker.unit_instance_id, accuracy_skill.id)
    var reduced_hit = core.action_cast_service.resolve_hit(command, accuracy_skill, gojo_unit, battle_state, content_index)
    if abs(float(reduced_hit.get("hit_rate", -1.0)) - 0.85) > 0.0001:
        return harness.fail_result("无下限应把 95 命中的敌方来袭技能压到 85")
    accuracy_skill.accuracy = 100
    var guaranteed_hit = core.action_cast_service.resolve_hit(command, accuracy_skill, gojo_unit, battle_state, content_index)
    if guaranteed_hit.get("hit_roll", "not-null") != null or abs(float(guaranteed_hit.get("hit_rate", -1.0)) - 1.0) > 0.0001:
        return harness.fail_result("无下限不应影响 100 命中的必中动作")
    _set_field_state(battle_state, "sukuna_malevolent_shrine", attacker.unit_instance_id)
    accuracy_skill.accuracy = 90
    var field_override_hit = core.action_cast_service.resolve_hit(command, accuracy_skill, gojo_unit, battle_state, content_index)
    if field_override_hit.get("hit_roll", "not-null") != null or abs(float(field_override_hit.get("hit_rate", -1.0)) - 1.0) > 0.0001:
        return harness.fail_result("无下限不应影响领域 creator_accuracy_override 带来的必中")
    return harness.pass_result()
func _test_gojo_mugen_reentry_contract(harness) -> Dictionary:
    var state_payload = _build_sample_vs_gojo_state(harness, 1211, false)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_wait_command(core, 1, "P1", "P1-A"),
        _build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
    ])
    if gojo_unit.leave_state == "active" or _count_rule_mod_instances(gojo_unit, "incoming_accuracy") != 0:
        return harness.fail_result("gojo 离场后应清掉当前入场时挂上的 incoming_accuracy rule_mod")
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_wait_command(core, 2, "P1", "P1-A"),
        _build_switch_command(core, 2, "P2", "P2-B", "P2-A"),
    ])
    var reentered_gojo = battle_state.get_side("P2").get_active_unit()
    if reentered_gojo == null or reentered_gojo.definition_id != "gojo_satoru":
        return harness.fail_result("gojo should return to active slot after switching back in")
    if _count_rule_mod_instances(reentered_gojo, "incoming_accuracy") != 1:
        return harness.fail_result("gojo 再入场后应重新挂上 incoming_accuracy rule_mod")
    var attacker = battle_state.get_side("P1").get_active_unit()
    var accuracy_skill = _build_accuracy_skill("test_gojo_mugen_reentry_95", 95)
    var command = _build_resolved_skill_command(core, 2, "P1", attacker.public_id, attacker.unit_instance_id, accuracy_skill.id)
    var hit_info = core.action_cast_service.resolve_hit(command, accuracy_skill, reentered_gojo, battle_state, content_index)
    if abs(float(hit_info.get("hit_rate", -1.0)) - 0.85) > 0.0001:
        return harness.fail_result("gojo 再入场后无下限仍应把来袭 95 命中压到 85")
    return harness.pass_result()
func _test_gojo_unlimited_void_runtime_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1212)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    gojo_unit.current_mp = gojo_unit.max_mp
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
        return harness.fail_result("无量空处命中后应施加无量空处领域")
    if int(gojo_unit.stat_stages.get("sp_attack", 0)) != 1:
        return harness.fail_result("无量空处应在 on_cast 阶段给自己 sp_attack +1")
    if not _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.EFFECT_APPLY_FIELD \
            and ev.field_change != null \
            and ev.field_change.after_field_id == "gojo_unlimited_void_field"
    ):
        return harness.fail_result("无量空处命中后应写出领域施加日志")
    if not _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and ev.target_instance_id == target_unit.unit_instance_id
    ):
        return harness.fail_result("无量空处命中后应对目标写出 deny all rule_mod 施加日志")
    var lock_payload = content_index.effects["gojo_domain_action_lock"].payloads[0]
    if core.rule_mod_service.create_instance(lock_payload, {"scope": "unit", "id": target_unit.unit_instance_id}, battle_state, "test_gojo_domain_lock", 0, gojo_unit.base_speed) == null:
        return harness.fail_result("failed to create gojo deny all rule_mod instance")
    var target_actions = core.legal_action_service.get_legal_actions(battle_state, "P2", content_index)
    if not target_actions.wait_allowed or not target_actions.legal_skill_ids.is_empty() or not target_actions.legal_ultimate_ids.is_empty() or not target_actions.legal_switch_target_public_ids.is_empty():
        return harness.fail_result("gojo deny all rule_mod 应只保留 wait 合法")
    content_index.skills["gojo_ao"].accuracy = 1
    var hit_command = _build_resolved_skill_command(core, 2, "P1", "P1-A", gojo_unit.unit_instance_id, "gojo_ao")
    var hit_info = core.action_cast_service.resolve_hit(hit_command, content_index.skills["gojo_ao"], target_unit, battle_state, content_index)
    if hit_info.get("hit_roll", "not-null") != null or abs(float(hit_info.get("hit_rate", -1.0)) - 1.0) > 0.0001:
        return harness.fail_result("无量空处领域内 creator_accuracy_override 应让 Gojo 的技能必中")
    return harness.pass_result()
func _test_gojo_unlimited_void_cancelled_pre_start_contract(harness) -> Dictionary:
    var cases: Array = [
        {
            "name": "skill",
            "command": func(core): return _build_skill_command(core, 1, "P2", "P2-A", "sample_strike"),
        },
        {
            "name": "ultimate",
            "command": func(core): return _build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
            "opponent": "sukuna",
        },
        {
            "name": "switch",
            "command": func(core): return _build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
        },
    ]
    for i in range(cases.size()):
        var use_sukuna: bool = String(cases[i].get("opponent", "sample")) == "sukuna"
        var state_payload = _build_gojo_battle_state(harness, 1213 + i, use_sukuna, true)
        if state_payload.has("error"):
            return harness.fail_result(str(state_payload["error"]))
        var core = state_payload["core"]
        var content_index = state_payload["content_index"]
        var battle_state = state_payload["battle_state"]
        var gojo_unit = battle_state.get_side("P1").get_active_unit()
        gojo_unit.current_mp = gojo_unit.max_mp
        core.battle_logger.reset()
        core.turn_loop_controller.run_turn(battle_state, content_index, [
            _build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
            cases[i]["command"].call(core),
        ])
        var opponent = _find_unit_on_side(battle_state, "P2", "sukuna" if use_sukuna else "sample_pyron")
        if opponent == null:
            return harness.fail_result("missing opponent unit for unlimited void cancel test")
        if not _has_event(core.battle_logger.event_log, func(ev):
            return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and ev.target_instance_id == opponent.unit_instance_id
        ):
            return harness.fail_result("无量空处先手命中后应把对方未开始的 %s 动作标记为 cancelled_pre_start" % cases[i]["name"])
        if _has_event(core.battle_logger.event_log, func(ev):
            return ev.event_type == EventTypesScript.ACTION_CAST and ev.actor_id == opponent.unit_instance_id
        ):
            return harness.fail_result("被无量空处锁住的 %s 动作不应走到 ACTION_CAST" % cases[i]["name"])
    return harness.pass_result()
func _test_gojo_reverse_ritual_heal_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var ritual_loadout: PackedStringArray = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
    var battle_setup = sample_factory.build_gojo_vs_sample_setup({"P1": {0: ritual_loadout}})
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1216, battle_setup)
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    if gojo_unit == null:
        return harness.fail_result("missing gojo active unit")
    gojo_unit.current_hp = max(1, int(floor(float(gojo_unit.max_hp) * 0.5)))
    var before_hp: int = gojo_unit.current_hp
    var expected_gain: int = min(gojo_unit.max_hp - before_hp, max(1, int(floor(float(gojo_unit.max_hp) * 0.25))))
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_reverse_ritual"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if gojo_unit.current_hp - before_hp != expected_gain:
        return harness.fail_result("反转术式应回复 25%% max_hp")
    return harness.pass_result()
func _test_gojo_plus5_competition_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_battle_state(harness, 1217, true, true)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var sukuna_unit = battle_state.get_side("P2").get_active_unit()
    gojo_unit.current_mp = gojo_unit.max_mp
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.base_speed = 999
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
    ])
    if not _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_CAST and ev.source_instance_id.find("action_") != -1 and ev.target_instance_id == gojo_unit.unit_instance_id
    ):
        return harness.fail_result("同优先级 +5 且对手更快时，对手应先正常行动")
    if _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and ev.target_instance_id == sukuna_unit.unit_instance_id
    ):
        return harness.fail_result("同优先级 +5 且对手先动时，Gojo 不应被误写成仍能首回合锁住对方")
    return harness.pass_result()
func _test_gojo_marker_switch_lifecycle_contract(harness) -> Dictionary:
    var leave_target_payload = _build_gojo_vs_sample_state(harness, 1218)
    if leave_target_payload.has("error"):
        return harness.fail_result(str(leave_target_payload["error"]))
    var core = leave_target_payload["core"]
    var content_index = leave_target_payload["content_index"]
    var battle_state = leave_target_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    _apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_wait_command(core, 1, "P1", "P1-A"),
        _build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
    ])
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
        return harness.fail_result("标记持有者离场时应清掉双标记")
    var leave_gojo_payload = _build_gojo_vs_sample_state(harness, 1219)
    if leave_gojo_payload.has("error"):
        return harness.fail_result(str(leave_gojo_payload["error"]))
    var core_2 = leave_gojo_payload["core"]
    var content_index_2 = leave_gojo_payload["content_index"]
    var battle_state_2 = leave_gojo_payload["battle_state"]
    var gojo_unit_2 = battle_state_2.get_side("P1").get_active_unit()
    var target_unit_2 = battle_state_2.get_side("P2").get_active_unit()
    _apply_gojo_double_marks(core_2, content_index_2, battle_state_2, target_unit_2, gojo_unit_2.unit_instance_id, gojo_unit_2.base_speed)
    core_2.turn_loop_controller.run_turn(battle_state_2, content_index_2, [
        _build_switch_command(core_2, 1, "P1", "P1-A", "P1-B"),
        _build_wait_command(core_2, 1, "P2", "P2-A"),
    ])
    if _count_effect_instances(target_unit_2, "gojo_ao_mark") != 1 or _count_effect_instances(target_unit_2, "gojo_aka_mark") != 1:
        return harness.fail_result("Gojo 自己离场时不应清掉目标身上的双标记")
    return harness.pass_result()
func _test_gojo_marker_refresh_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1220)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_ao"].accuracy = 100
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    var first_mark = _find_effect_instance(target_unit, "gojo_ao_mark")
    if first_mark == null or first_mark.remaining != 2:
        return harness.fail_result("苍标记首回合施加后应在 turn_end 后剩余 2")
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_wait_command(core, 2, "P1", "P1-A"),
        _build_wait_command(core, 2, "P2", "P2-A"),
    ])
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 3, "P1", "P1-A", "gojo_ao"),
        _build_wait_command(core, 3, "P2", "P2-A"),
    ])
    var refreshed_mark = _find_effect_instance(target_unit, "gojo_ao_mark")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 1:
        return harness.fail_result("苍标记 refresh 语义下不应并行出第二层同名标记")
    if refreshed_mark == null or refreshed_mark.remaining != 2:
        return harness.fail_result("苍标记 refresh 后应重置持续时间，而不是继续沿用旧剩余回合")
    return harness.pass_result()
func _build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
    return _build_gojo_battle_state(harness, seed, false, true)
func _build_sample_vs_gojo_state(harness, seed: int, use_sukuna: bool) -> Dictionary:
    return _build_gojo_battle_state(harness, seed, use_sukuna, false)
func _build_gojo_battle_state(harness, seed: int, use_sukuna: bool, gojo_on_p1: bool) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return {"error": str(core_payload["error"])}
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return {"error": "SampleBattleFactory init failed"}
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = sample_factory.build_sample_setup()
    if use_sukuna:
        battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_pyron"]) if gojo_on_p1 else PackedStringArray(["sukuna", "sample_tidekit", "sample_mossaur"])
        battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sukuna", "sample_tidekit", "sample_mossaur"]) if gojo_on_p1 else PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
    else:
        battle_setup.sides[0].unit_definition_ids = PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"]) if gojo_on_p1 else PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"])
        battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_pyron", "sample_tidekit", "sample_mossaur"]) if gojo_on_p1 else PackedStringArray(["gojo_satoru", "sample_mossaur", "sample_tidekit"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].starting_index = 0
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, seed, battle_setup)
    return {
        "core": core,
        "content_index": content_index,
        "battle_state": battle_state,
    }
func _build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "skill_id": skill_id,
    })
func _build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.ULTIMATE,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "skill_id": skill_id,
    })
func _build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
    })
func _build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.SWITCH,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "target_public_id": target_public_id,
    })
func _build_resolved_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, actor_id: String, skill_id: String):
    var command = _build_skill_command(core, turn_index, side_id, actor_public_id, skill_id)
    command.actor_id = actor_id
    return command
func _build_accuracy_skill(skill_id: String, accuracy: int):
    var skill = SkillDefinitionScript.new()
    skill.id = skill_id
    skill.display_name = skill_id
    skill.damage_kind = "none"
    skill.power = 0
    skill.accuracy = accuracy
    skill.mp_cost = 0
    skill.priority = 0
    skill.targeting = "enemy_active_slot"
    return skill
func _apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id: String, source_speed: int) -> void:
    core.effect_instance_service.create_instance(content_index.effects["gojo_ao_mark"], target_unit.unit_instance_id, battle_state, source_instance_id, 0, source_speed)
    core.effect_instance_service.create_instance(content_index.effects["gojo_aka_mark"], target_unit.unit_instance_id, battle_state, source_instance_id, 0, source_speed)
func _set_field_state(battle_state, field_id: String, creator_id: String) -> void:
    var field_state = FieldStateScript.new()
    field_state.field_def_id = field_id
    field_state.instance_id = "test_field_%s" % field_id
    field_state.creator = creator_id
    battle_state.field_state = field_state
func _find_unit_on_side(battle_state, side_id: String, definition_id: String):
    var side_state = battle_state.get_side(side_id)
    if side_state == null:
        return null
    for unit_state in side_state.team_units:
        if unit_state.definition_id == definition_id:
            return unit_state
    return null
func _find_effect_instance(unit_state, effect_id: String):
    for effect_instance in unit_state.effect_instances:
        if effect_instance.def_id == effect_id:
            return effect_instance
    return null
func _count_effect_instances(unit_state, effect_id: String) -> int:
    var count: int = 0
    for effect_instance in unit_state.effect_instances:
        if effect_instance.def_id == effect_id:
            count += 1
    return count
func _count_rule_mod_instances(unit_state, mod_kind: String) -> int:
    var count: int = 0
    for rule_mod_instance in unit_state.rule_mod_instances:
        if rule_mod_instance.mod_kind == mod_kind:
            count += 1
    return count
func _count_target_damage_events(event_log: Array, target_unit_id: String) -> int:
    var count: int = 0
    for ev in event_log:
        if ev.event_type == EventTypesScript.EFFECT_DAMAGE and ev.target_instance_id == target_unit_id:
            count += 1
    return count
func _has_event(event_log: Array, predicate: Callable) -> bool:
    for ev in event_log:
        if bool(predicate.call(ev)):
            return true
    return false
