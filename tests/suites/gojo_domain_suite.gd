extends RefCounted
class_name GojoDomainSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("gojo_mugen_incoming_accuracy_contract", failures, Callable(self, "_test_gojo_mugen_incoming_accuracy_contract").bind(harness))
    runner.run_test("gojo_mugen_reentry_contract", failures, Callable(self, "_test_gojo_mugen_reentry_contract").bind(harness))
    runner.run_test("gojo_unlimited_void_runtime_contract", failures, Callable(self, "_test_gojo_unlimited_void_runtime_contract").bind(harness))
    runner.run_test("gojo_unlimited_void_cancelled_pre_start_contract", failures, Callable(self, "_test_gojo_unlimited_void_cancelled_pre_start_contract").bind(harness))
    runner.run_test("gojo_reverse_ritual_heal_contract", failures, Callable(self, "_test_gojo_reverse_ritual_heal_contract").bind(harness))
    runner.run_test("gojo_plus5_competition_contract", failures, Callable(self, "_test_gojo_plus5_competition_contract").bind(harness))
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
    _set_field_state(battle_state, "sukuna_malevolent_shrine_field", attacker.unit_instance_id)
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
    gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
        return harness.fail_result("无量空处命中后应施加无量空处领域")
    if int(gojo_unit.stat_stages.get("sp_attack", 0)) != 1:
        return harness.fail_result("无量空处领域成功立住时应给自己 sp_attack +1")
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
            "expect_cancelled": true,
        },
        {
            "name": "ultimate",
            "command": func(core): return _build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
            "opponent": "sukuna",
            "expect_cancelled": false,
        },
        {
            "name": "switch",
            "command": func(core): return _build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
            "expect_cancelled": true,
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
        gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
        if use_sukuna:
            var sukuna_unit = battle_state.get_side("P2").get_active_unit()
            sukuna_unit.current_mp = sukuna_unit.max_mp
            sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
        core.battle_logger.reset()
        core.turn_loop_controller.run_turn(battle_state, content_index, [
            _build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
            cases[i]["command"].call(core),
        ])
        var opponent = _find_unit_on_side(battle_state, "P2", "sukuna" if use_sukuna else "sample_pyron")
        if opponent == null:
            return harness.fail_result("missing opponent unit for unlimited void cancel test")
        if bool(cases[i]["expect_cancelled"]):
            if not _has_event(core.battle_logger.event_log, func(ev):
                return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and ev.target_instance_id == opponent.unit_instance_id
            ):
                return harness.fail_result("无量空处先手命中后应把对方未开始的 %s 动作标记为 cancelled_pre_start" % cases[i]["name"])
            if _has_event(core.battle_logger.event_log, func(ev):
                return ev.event_type == EventTypesScript.ACTION_CAST and ev.actor_id == opponent.unit_instance_id
            ):
                return harness.fail_result("被无量空处锁住的 %s 动作不应走到 ACTION_CAST" % cases[i]["name"])
            continue
        if not _has_event(core.battle_logger.event_log, func(ev):
            return ev.event_type == EventTypesScript.ACTION_CAST and ev.actor_id == opponent.unit_instance_id
        ):
            return harness.fail_result("双方同回合开领域时，对手 %s 动作不应被 action_lock 抢先取消" % cases[i]["name"])
        if not _has_event(core.battle_logger.event_log, func(ev):
            return ev.event_type == EventTypesScript.EFFECT_FIELD_CLASH
        ):
            return harness.fail_result("双方同回合开领域时必须写出领域对拼日志")
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
    gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
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

func _build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
    return _support.build_gojo_vs_sample_state(harness, seed)

func _build_sample_vs_gojo_state(harness, seed: int, use_sukuna: bool) -> Dictionary:
    return _support.build_sample_vs_gojo_state(harness, seed, use_sukuna)

func _build_gojo_battle_state(harness, seed: int, use_sukuna: bool, gojo_on_p1: bool) -> Dictionary:
    return _support.build_gojo_battle_state(harness, seed, use_sukuna, gojo_on_p1)

func _build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _support.build_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _support.build_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return _support.build_wait_command(core, turn_index, side_id, actor_public_id)

func _build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
    return _support.build_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func _build_resolved_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, actor_id: String, skill_id: String):
    return _support.build_resolved_skill_command(core, turn_index, side_id, actor_public_id, actor_id, skill_id)

func _build_accuracy_skill(skill_id: String, accuracy: int):
    return _support.build_accuracy_skill(skill_id, accuracy)

func _apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id: String, source_speed: int) -> void:
    _support.apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id, source_speed)

func _set_field_state(battle_state, field_id: String, creator_id: String) -> void:
    _support.set_field_state(battle_state, field_id, creator_id)

func _find_unit_on_side(battle_state, side_id: String, definition_id: String):
    return _support.find_unit_on_side(battle_state, side_id, definition_id)

func _find_effect_instance(unit_state, effect_id: String):
    return _support.find_effect_instance(unit_state, effect_id)

func _count_effect_instances(unit_state, effect_id: String) -> int:
    return _support.count_effect_instances(unit_state, effect_id)

func _count_rule_mod_instances(unit_state, mod_kind: String) -> int:
    return _support.count_rule_mod_instances(unit_state, mod_kind)

func _count_target_damage_events(event_log: Array, target_unit_id: String) -> int:
    return _support.count_target_damage_events(event_log, EventTypesScript.EFFECT_DAMAGE, target_unit_id)

func _has_event(event_log: Array, predicate: Callable) -> bool:
    return _support.has_event(event_log, predicate)
