extends RefCounted
class_name KashimoRuntimeSuite

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _support = KashimoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("kashimo_raiken_negative_charge_contract", failures, Callable(self, "_test_kashimo_raiken_negative_charge_contract").bind(harness))
    runner.run_test("kashimo_charge_positive_charge_contract", failures, Callable(self, "_test_kashimo_charge_positive_charge_contract").bind(harness))
    runner.run_test("kashimo_feedback_strike_dynamic_power_and_clear_contract", failures, Callable(self, "_test_kashimo_feedback_strike_dynamic_power_and_clear_contract").bind(harness))
    runner.run_test("kashimo_kyokyo_katsura_nullify_field_accuracy_contract", failures, Callable(self, "_test_kashimo_kyokyo_katsura_nullify_field_accuracy_contract").bind(harness))
    runner.run_test("kashimo_thunder_resist_contract", failures, Callable(self, "_test_kashimo_thunder_resist_contract").bind(harness))
    runner.run_test("kashimo_water_leak_counter_contract", failures, Callable(self, "_test_kashimo_water_leak_counter_contract").bind(harness))

func _test_kashimo_raiken_negative_charge_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _support.build_kashimo_setup(sample_factory)
    battle_setup.sides[1].starting_index = 2
    var battle_state = _support.build_battle_state(core, content_index, battle_setup, 801)
    var kashimo = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if kashimo == null or target == null:
        return harness.fail_result("missing active units for raiken contract")
    var expected_tick: int = _support.calc_expected_fixed_effect_damage(core, content_index, "kashimo_negative_charge_mark", target)
    if expected_tick <= 0:
        return harness.fail_result("failed to resolve negative charge expected damage")
    for turn_index in range(1, 4):
        core.battle_logger.reset()
        core.turn_loop_controller.run_turn(battle_state, content_index, [
            _support.build_manual_skill_command(core, turn_index, "P1", "P1-A", "kashimo_raiken"),
            _support.build_manual_wait_command(core, turn_index, "P2", "P2-C"),
        ])
        var stack_count: int = _support.count_effect_instances(target, "kashimo_negative_charge_mark")
        if stack_count != turn_index:
            return harness.fail_result("raiken should leave %d negative charge stacks after turn %d, actual=%d" % [turn_index, turn_index, stack_count])
        var tick_deltas: Array[int] = _collect_trigger_damage_deltas(core.battle_logger.event_log, target.unit_instance_id, "turn_end")
        if tick_deltas.size() != turn_index:
            return harness.fail_result("negative charge should emit %d turn_end ticks on turn %d, actual=%d" % [turn_index, turn_index, tick_deltas.size()])
        for tick_delta in tick_deltas:
            if tick_delta != expected_tick:
                return harness.fail_result("negative charge tick mismatch on turn %d: expected=%d actual=%d" % [turn_index, expected_tick, tick_delta])
    return harness.pass_result()

func _test_kashimo_charge_positive_charge_contract(harness) -> Dictionary:
    var state_payload = _build_kashimo_state(harness, 802)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var kashimo = battle_state.get_side("P1").get_active_unit()
    if kashimo == null:
        return harness.fail_result("missing kashimo active unit for charge contract")
    for turn_index in range(1, 4):
        core.turn_loop_controller.run_turn(battle_state, content_index, [
            _support.build_manual_skill_command(core, turn_index, "P1", "P1-A", "kashimo_charge"),
            _support.build_manual_wait_command(core, turn_index, "P2", "P2-A"),
        ])
    if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 3:
        return harness.fail_result("charge should leave three positive charge stacks after three casts")
    var mp_before_turn_four: int = kashimo.current_mp
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_manual_wait_command(core, 4, "P1", "P1-A"),
        _support.build_manual_wait_command(core, 4, "P2", "P2-A"),
    ])
    var plus_five_events: int = 0
    for event in core.battle_logger.event_log:
        if event.event_type != EventTypesScript.EFFECT_RESOURCE_MOD:
            continue
        if String(event.trigger_name) != "turn_start" or String(event.target_instance_id) != String(kashimo.unit_instance_id):
            continue
        if event.value_changes.is_empty():
            continue
        if int(event.value_changes[0].delta) == 5:
            plus_five_events += 1
    if plus_five_events != 3:
        return harness.fail_result("positive charge should emit exactly three +5 mp ticks on turn 4, actual=%d" % plus_five_events)
    if kashimo.current_mp - mp_before_turn_four != 25:
        return harness.fail_result("positive charge turn 4 total mp delta mismatch: expected=25 actual=%d" % (kashimo.current_mp - mp_before_turn_four))
    return harness.pass_result()

func _test_kashimo_feedback_strike_dynamic_power_and_clear_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _support.build_kashimo_setup(sample_factory)
    battle_setup.sides[1].starting_index = 2
    var battle_state = _support.build_battle_state(core, content_index, battle_setup, 803)
    var kashimo = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if kashimo == null or target == null:
        return harness.fail_result("missing active units for feedback strike contract")
    var positive_mark = content_index.effects.get("kashimo_positive_charge_mark", null)
    var negative_mark = content_index.effects.get("kashimo_negative_charge_mark", null)
    if positive_mark == null or negative_mark == null:
        return harness.fail_result("missing charge mark definitions for feedback strike contract")
    for _i in range(2):
        if core.effect_instance_service.create_instance(positive_mark, kashimo.unit_instance_id, battle_state, "test_feedback_positive", 0, kashimo.base_speed) == null:
            return harness.fail_result("failed to seed positive charges for feedback strike contract")
        if core.effect_instance_service.create_instance(negative_mark, target.unit_instance_id, battle_state, "test_feedback_negative", 0, kashimo.base_speed) == null:
            return harness.fail_result("failed to seed negative charges for feedback strike contract")
    if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 2:
        return harness.fail_result("feedback strike setup should leave two positive charges before cast")
    if _support.count_effect_instances(target, "kashimo_negative_charge_mark") != 2:
        return harness.fail_result("feedback strike setup should leave two negative charges before cast")
    var expected_power: int = 30 + 12 * 4
    var expected_damage: int = core.damage_service.apply_final_mod(
        core.damage_service.calc_base_damage(
            battle_state.battle_level,
            expected_power,
            kashimo.base_sp_attack,
            target.base_sp_defense
        ),
        core.combat_type_service.calc_effectiveness("thunder", target.combat_type_ids)
    )
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "kashimo_feedback_strike"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-C"),
    ])
    var actual_damage: int = harness.extract_damage_from_log(core.battle_logger.event_log, "P1-A")
    if actual_damage != expected_damage:
        return harness.fail_result("feedback strike damage mismatch: expected=%d actual=%d" % [expected_damage, actual_damage])
    if _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark") != 0:
        return harness.fail_result("feedback strike should clear all positive charges on hit")
    if _support.count_effect_instances(target, "kashimo_negative_charge_mark") != 0:
        return harness.fail_result("feedback strike should clear all negative charges on hit")
    return harness.pass_result()

func _test_kashimo_kyokyo_katsura_nullify_field_accuracy_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var zero_skill = SkillDefinitionScript.new()
    zero_skill.id = "test_kashimo_zero_accuracy_domain_hit"
    zero_skill.display_name = "Kashimo Zero Accuracy Domain Hit"
    zero_skill.damage_kind = "special"
    zero_skill.power = 40
    zero_skill.accuracy = 0
    zero_skill.mp_cost = 0
    zero_skill.priority = 0
    zero_skill.targeting = "enemy_active_slot"
    zero_skill.combat_type_id = "fire"
    content_index.register_resource(zero_skill)
    content_index.units["sample_tidekit"].skill_ids[0] = zero_skill.id

    var baseline_setup = _support.build_kashimo_setup(sample_factory)
    var baseline_state = _support.build_battle_state(core, content_index, baseline_setup, 804)
    var baseline_target = baseline_state.get_side("P1").get_active_unit()
    var baseline_actor = baseline_state.get_side("P2").get_active_unit()
    if baseline_target == null or baseline_actor == null:
        return harness.fail_result("missing active units for kyokyo baseline contract")
    baseline_state.field_state = _build_override_field_state("gojo_unlimited_void_field", baseline_actor.unit_instance_id)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(baseline_state, content_index, [
        _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-A", zero_skill.id),
    ])
    if harness.extract_damage_from_log(core.battle_logger.event_log, "P2-A") <= 0:
        return harness.fail_result("domain accuracy override should force zero-accuracy skill to hit before kyokyo")

    var protected_setup = _support.build_kashimo_setup(sample_factory)
    var protected_state = _support.build_battle_state(core, content_index, protected_setup, 805)
    var protected_target = protected_state.get_side("P1").get_active_unit()
    var protected_actor = protected_state.get_side("P2").get_active_unit()
    if protected_target == null or protected_actor == null:
        return harness.fail_result("missing active units for kyokyo protected contract")
    protected_state.field_state = _build_override_field_state("gojo_unlimited_void_field", protected_actor.unit_instance_id)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(protected_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "kashimo_kyokyo_katsura"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-A", zero_skill.id),
    ])
    if harness.extract_damage_from_log(core.battle_logger.event_log, "P2-A") != 0:
        return harness.fail_result("kyokyo katsura should restore original miss rate under domain accuracy override")
    return harness.pass_result()

func _test_kashimo_thunder_resist_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var baseline_content = harness.build_loaded_content_index(sample_factory)
    var thunder_skill = SkillDefinitionScript.new()
    thunder_skill.id = "test_kashimo_incoming_thunder"
    thunder_skill.display_name = "Incoming Thunder"
    thunder_skill.damage_kind = "special"
    thunder_skill.power = 50
    thunder_skill.accuracy = 100
    thunder_skill.mp_cost = 0
    thunder_skill.priority = 0
    thunder_skill.targeting = "enemy_active_slot"
    thunder_skill.combat_type_id = "thunder"
    baseline_content.register_resource(thunder_skill)
    baseline_content.units["sample_tidekit"].skill_ids[0] = thunder_skill.id
    baseline_content.units["kashimo_hajime"].passive_skill_id = ""
    var baseline_state = _support.build_battle_state(core, baseline_content, _support.build_kashimo_setup(sample_factory), 806)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(baseline_state, baseline_content, [
        _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-A", thunder_skill.id),
    ])
    var baseline_damage: int = harness.extract_damage_from_log(core.battle_logger.event_log, "P2-A")
    if baseline_damage <= 0:
        return harness.fail_result("missing baseline thunder damage against kashimo")

    var resisted_content = harness.build_loaded_content_index(sample_factory)
    resisted_content.register_resource(thunder_skill)
    resisted_content.units["sample_tidekit"].skill_ids[0] = thunder_skill.id
    var resisted_state = _support.build_battle_state(core, resisted_content, _support.build_kashimo_setup(sample_factory), 807)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(resisted_state, resisted_content, [
        _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-A", thunder_skill.id),
    ])
    var resisted_damage: int = harness.extract_damage_from_log(core.battle_logger.event_log, "P2-A")
    var expected_resisted_damage: int = core.damage_service.apply_final_mod(baseline_damage, 0.5)
    if resisted_damage != expected_resisted_damage:
        return harness.fail_result("kashimo thunder resist mismatch: expected=%d actual=%d baseline=%d" % [expected_resisted_damage, resisted_damage, baseline_damage])
    return harness.pass_result()

func _test_kashimo_water_leak_counter_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var water_skill = SkillDefinitionScript.new()
    water_skill.id = "test_kashimo_incoming_water"
    water_skill.display_name = "Incoming Water"
    water_skill.damage_kind = "special"
    water_skill.power = 40
    water_skill.accuracy = 100
    water_skill.mp_cost = 0
    water_skill.priority = 0
    water_skill.targeting = "enemy_active_slot"
    water_skill.combat_type_id = "water"
    content_index.register_resource(water_skill)
    content_index.units["sample_mossaur"].skill_ids[0] = water_skill.id
    var battle_setup = _support.build_kashimo_setup(sample_factory)
    battle_setup.sides[1].starting_index = 2
    var battle_state = _support.build_battle_state(core, content_index, battle_setup, 808)
    var kashimo = battle_state.get_side("P1").get_active_unit()
    var attacker = battle_state.get_side("P2").get_active_unit()
    if kashimo == null or attacker == null:
        return harness.fail_result("missing active units for water leak contract")
    kashimo.current_hp = 1
    kashimo.current_mp = 20
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-C", water_skill.id),
    ])
    if kashimo.current_hp != 0:
        return harness.fail_result("water leak contract should still allow lethal hit to KO kashimo")
    if kashimo.current_mp != 5:
        return harness.fail_result("water leak should reduce kashimo mp by 15 even on lethal hit: expected=5 actual=%d" % kashimo.current_mp)
    var expected_counter_damage: int = _support.calc_expected_fixed_effect_damage(core, content_index, "kashimo_water_leak_counter_listener", attacker)
    var actual_counter_damage: int = _find_counter_damage(core.battle_logger.event_log, attacker.unit_instance_id)
    if actual_counter_damage != expected_counter_damage:
        return harness.fail_result("water leak counter damage mismatch: expected=%d actual=%d" % [expected_counter_damage, actual_counter_damage])
    return harness.pass_result()

func _build_kashimo_state(harness, seed: int) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return core_payload
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return {"error": "SampleBattleFactory init failed"}
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory), seed)
    return {
        "core": core,
        "content_index": content_index,
        "battle_state": battle_state,
    }

func _collect_trigger_damage_deltas(event_log: Array, target_instance_id: String, trigger_name: String) -> Array[int]:
    var deltas: Array[int] = []
    for event in event_log:
        if event.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(event.target_instance_id) != target_instance_id:
            continue
        if String(event.trigger_name) != trigger_name:
            continue
        if event.value_changes.is_empty():
            continue
        deltas.append(abs(int(event.value_changes[0].delta)))
    return deltas

func _find_counter_damage(event_log: Array, target_instance_id: String) -> int:
    for event in event_log:
        if event.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(event.target_instance_id) != target_instance_id:
            continue
        if String(event.trigger_name) != "on_receive_action_hit":
            continue
        if event.value_changes.is_empty():
            continue
        return abs(int(event.value_changes[0].delta))
    return 0

func _build_override_field_state(field_def_id: String, creator_id: String):
    var field_state = preload("res://src/battle_core/runtime/field_state.gd").new()
    field_state.field_def_id = field_def_id
    field_state.instance_id = "test_kashimo_field_override"
    field_state.creator = creator_id
    field_state.remaining_turns = 3
    return field_state
