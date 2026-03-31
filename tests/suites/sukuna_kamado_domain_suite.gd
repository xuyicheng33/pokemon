extends RefCounted
class_name SukunaKamadoDomainSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

var _support = SukunaTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("sukuna_kamado_stack_on_exit_path", failures, Callable(self, "_test_sukuna_kamado_stack_on_exit_path").bind(harness))
    runner.run_test("sukuna_kamado_stack_cap_path", failures, Callable(self, "_test_sukuna_kamado_stack_cap_path").bind(harness))
    runner.run_test("sukuna_kamado_forced_replace_on_exit_path", failures, Callable(self, "_test_sukuna_kamado_forced_replace_on_exit_path").bind(harness))
    runner.run_test("sukuna_domain_expire_chain_path", failures, Callable(self, "_test_sukuna_domain_expire_chain_path").bind(harness))
    runner.run_test("sukuna_domain_break_chain_path", failures, Callable(self, "_test_sukuna_domain_break_chain_path").bind(harness))
    runner.run_test("sukuna_domain_break_on_faint_path", failures, Callable(self, "_test_sukuna_domain_break_on_faint_path").bind(harness))
    runner.run_test("sukuna_field_accuracy_override_path", failures, Callable(self, "_test_sukuna_field_accuracy_override_path").bind(harness))

func _test_sukuna_kamado_stack_on_exit_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hiraku"].accuracy = 100
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 703)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for kamado stack test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 2, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    var kamado_instances: Array = []
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            kamado_instances.append(effect_instance)
    if kamado_instances.size() != 2:
        return harness.fail_result("double hiraku should leave exactly two kamado stacks before exit")
    target_unit.current_hp = target_unit.max_hp
    var hp_before_exit: int = target_unit.current_hp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 3, "P1", "P1-A"),
        core.command_builder.build_command({
            "turn_index": 3,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "target_public_id": "P2-B",
        }),
    ])
    var on_exit_damage_events: int = 0
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_DAMAGE \
        and log_event.trigger_name == "on_exit" \
        and log_event.target_instance_id == target_unit.unit_instance_id:
            on_exit_damage_events += 1
    var expected_on_exit_damage := _calc_expected_fixed_effect_damage(core, content_index, "sukuna_kamado_mark", target_unit) * 2
    if hp_before_exit - target_unit.current_hp != expected_on_exit_damage:
        return harness.fail_result("double kamado on_exit damage mismatch: delta=%d expected=%d events=%d" % [
            hp_before_exit - target_unit.current_hp,
            expected_on_exit_damage,
            on_exit_damage_events,
        ])
    if on_exit_damage_events != 2:
        return harness.fail_result("double kamado should emit two on_exit damage events")
    return harness.pass_result()

func _test_sukuna_kamado_stack_cap_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 707)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    var kamado_definition = content_index.effects.get("sukuna_kamado_mark", null)
    if sukuna_unit == null or target_unit == null or kamado_definition == null:
        return harness.fail_result("kamado stack cap test missing runtime or content state")
    var before_ids: Array[String] = []
    var before_remaining: Array[int] = []
    for stack_index in range(3):
        var created_instance = core.effect_instance_service.create_instance(
            kamado_definition,
            target_unit.unit_instance_id,
            battle_state,
            "test_kamado_stack_%d" % stack_index,
            1,
            sukuna_unit.base_speed
        )
        if created_instance == null:
            return harness.fail_result("kamado stack cap test failed to create baseline stack %d" % stack_index)
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            before_ids.append(effect_instance.instance_id)
            before_remaining.append(int(effect_instance.remaining))
    before_ids.sort()
    before_remaining.sort()
    var overflow_instance = core.effect_instance_service.create_instance(
        kamado_definition,
        target_unit.unit_instance_id,
        battle_state,
        "test_kamado_stack_overflow",
        1,
        sukuna_unit.base_speed
    )
    if overflow_instance == null:
        return harness.fail_result("kamado overflow apply should be ignored, not fail")
    if not core.effect_instance_service.last_apply_skipped:
        return harness.fail_result("kamado overflow apply should be marked as skipped once max_stacks is reached")
    var after_ids: Array[String] = []
    var after_remaining: Array[int] = []
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            after_ids.append(effect_instance.instance_id)
            after_remaining.append(int(effect_instance.remaining))
    after_ids.sort()
    after_remaining.sort()
    if after_ids.size() != 3:
        return harness.fail_result("kamado max_stacks should clamp to exactly three instances")
    if after_ids != before_ids:
        return harness.fail_result("kamado overflow apply should not replace existing stacks")
    if after_remaining != before_remaining:
        return harness.fail_result("kamado overflow apply should not refresh existing stack durations")
    return harness.pass_result()

func _test_sukuna_kamado_forced_replace_on_exit_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hiraku"].accuracy = 100
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 708)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for forced_replace kamado test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var hp_before_forced_replace: int = target_unit.current_hp
    battle_state.chain_context = core.battle_result_service.build_system_chain("system:replace")
    var replace_result: Dictionary = core.replacement_service.execute_forced_replace(
        battle_state,
        content_index,
        target_unit.unit_instance_id
    )
    if replace_result.get("invalid_code", null) != null:
        return harness.fail_result("forced_replace should not fail after kamado apply")
    if not bool(replace_result.get("replaced", false)):
        return harness.fail_result("forced_replace should replace kamado target with a bench unit")
    var forced_replace_on_exit_events: int = 0
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_DAMAGE \
        and log_event.trigger_name == "on_exit" \
        and log_event.target_instance_id == target_unit.unit_instance_id:
            forced_replace_on_exit_events += 1
    var expected_forced_replace_damage := _calc_expected_fixed_effect_damage(core, content_index, "sukuna_kamado_mark", target_unit)
    if hp_before_forced_replace - target_unit.current_hp != expected_forced_replace_damage:
        return harness.fail_result("forced_replace kamado on_exit damage mismatch: delta=%d expected=%d" % [
            hp_before_forced_replace - target_unit.current_hp,
            expected_forced_replace_damage,
        ])
    if forced_replace_on_exit_events != 1:
        return harness.fail_result("forced_replace should emit exactly one kamado on_exit damage event")
    return harness.pass_result()

func _test_sukuna_domain_expire_chain_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 704)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for domain expire test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 2, "P1", "P1-A"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    var hp_before_expire: int = target_unit.current_hp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 3, "P1", "P1-A"),
        _build_manual_wait_command(core, 3, "P2", "P2-A"),
    ])
    if battle_state.field_state != null:
        return harness.fail_result("malevolent shrine should expire after third turn")
    var expected_expire_damage := _calc_expected_fixed_effect_damage(core, content_index, "sukuna_domain_expire_burst", target_unit)
    if hp_before_expire - target_unit.current_hp != expected_expire_damage:
        return harness.fail_result("malevolent shrine expire burst damage mismatch: delta=%d expected=%d" % [
            hp_before_expire - target_unit.current_hp,
            expected_expire_damage,
        ])
    if int(sukuna_unit.stat_stages.get("attack", 0)) != 0 or int(sukuna_unit.stat_stages.get("sp_attack", 0)) != 0:
        return harness.fail_result("malevolent shrine 自然到期后应移除领域绑定增幅")
    var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not legal_action_set.legal_skill_ids.has("sukuna_kai") \
    or not legal_action_set.legal_skill_ids.has("sukuna_hatsu") \
    or not legal_action_set.legal_skill_ids.has("sukuna_hiraku"):
        return harness.fail_result("domain expire should not seal sukuna normal skills after removing post-domain cooldown")
    var has_field_expire_log: bool = false
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
            has_field_expire_log = true
            break
    if not has_field_expire_log:
        return harness.fail_result("domain expire log missing")
    return harness.pass_result()

func _test_sukuna_domain_break_chain_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 705)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for domain break test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var hp_before_break: int = target_unit.current_hp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "target_public_id": "P1-B",
        }),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    if battle_state.field_state != null:
        return harness.fail_result("malevolent shrine should break when creator leaves active slot")
    if target_unit.current_hp != hp_before_break:
        return harness.fail_result("field break should not trigger expire burst damage")
    if int(sukuna_unit.stat_stages.get("attack", 0)) != 0 or int(sukuna_unit.stat_stages.get("sp_attack", 0)) != 0:
        return harness.fail_result("malevolent shrine 打断后领域绑定增幅必须消失")
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
            return harness.fail_result("field break should not emit natural expire log")
        if log_event.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and String(log_event.payload_summary).find("skill_legality") != -1:
            return harness.fail_result("field break should not apply any post-domain seal rule_mod")
    return harness.pass_result()

func _test_sukuna_domain_break_on_faint_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 709)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for domain faint break test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    sukuna_unit.current_hp = 1
    var target_hp_before_faint_break: int = target_unit.current_hp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 2, "P1", "P1-A"),
        core.command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    if battle_state.field_state != null:
        return harness.fail_result("malevolent shrine should break immediately when creator faints")
    if target_unit.current_hp != target_hp_before_faint_break:
        return harness.fail_result("creator faint break should not trigger domain natural expire burst")
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
            return harness.fail_result("creator faint break should not emit natural field expire log")
    return harness.pass_result()

func _test_sukuna_field_accuracy_override_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hiraku"].accuracy = 0
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 706)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for field accuracy override test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var hp_before_cast: int = target_unit.current_hp
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 2, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    if target_unit.current_hp >= hp_before_cast:
        return harness.fail_result("field accuracy override should let zero-accuracy hiraku hit while domain is active")
    return harness.pass_result()


func _build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
    return _support.build_sukuna_setup(sample_factory, p1_regular_skill_overrides)

func _build_battle_state(core, content_index, battle_setup, seed: int):
    return _support.build_battle_state(core, content_index, battle_setup, seed)

func _build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return _support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func _calc_expected_fixed_effect_damage(core, content_index, effect_id: String, target_unit) -> int:
    var effect_definition = content_index.effects.get(effect_id, null)
    if effect_definition == null or effect_definition.payloads.is_empty():
        return -1
    var payload = effect_definition.payloads[0]
    var type_effectiveness := 1.0
    if not String(payload.combat_type_id).is_empty():
        type_effectiveness = core.combat_type_service.calc_effectiveness(String(payload.combat_type_id), target_unit.combat_type_ids)
    return core.damage_service.apply_final_mod(max(1, int(payload.amount)), type_effectiveness)
