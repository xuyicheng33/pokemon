extends "res://tests/suites/kashimo_runtime/base.gd"
const BaseSuiteScript := preload("res://tests/suites/kashimo_runtime/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("kashimo_kyokyo_katsura_nullify_field_accuracy_contract", failures, Callable(self, "_test_kashimo_kyokyo_katsura_nullify_field_accuracy_contract").bind(harness))
    runner.run_test("kashimo_kyokyo_katsura_refresh_contract", failures, Callable(self, "_test_kashimo_kyokyo_katsura_refresh_contract").bind(harness))

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
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(baseline_state, content_index, [
        _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-A", zero_skill.id),
    ])
    if harness.extract_damage_from_log(core.service("battle_logger").event_log, "P2-A") <= 0:
        return harness.fail_result("domain accuracy override should force zero-accuracy skill to hit before kyokyo")

    var protected_setup = _support.build_kashimo_setup(sample_factory)
    var protected_state = _support.build_battle_state(core, content_index, protected_setup, 805)
    var protected_target = protected_state.get_side("P1").get_active_unit()
    var protected_actor = protected_state.get_side("P2").get_active_unit()
    if protected_target == null or protected_actor == null:
        return harness.fail_result("missing active units for kyokyo protected contract")
    protected_state.field_state = _build_override_field_state("gojo_unlimited_void_field", protected_actor.unit_instance_id)
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(protected_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "kashimo_kyokyo_katsura"),
        _support.build_manual_skill_command(core, 1, "P2", "P2-A", zero_skill.id),
    ])
    if harness.extract_damage_from_log(core.service("battle_logger").event_log, "P2-A") != 0:
        return harness.fail_result("kyokyo katsura should restore original miss rate under domain accuracy override")
    return harness.pass_result()

func _test_kashimo_kyokyo_katsura_refresh_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var override_loadout := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])}
    var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory, override_loadout), 845)
    var kashimo = battle_state.get_side("P1").get_active_unit()
    if kashimo == null:
        return harness.fail_result("missing kashimo active unit for kyokyo refresh contract")
    kashimo.current_mp = kashimo.max_mp

    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 1, "P1", "P1-A", "kashimo_kyokyo_katsura"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var nullify_rule_mod = _find_rule_mod(kashimo, "nullify_field_accuracy")
    if nullify_rule_mod == null or int(nullify_rule_mod.remaining) != 2:
        return harness.fail_result("kyokyo first cast should leave nullify_field_accuracy with remaining=2 after turn_end")

    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_skill_command(core, 2, "P1", "P1-A", "kashimo_kyokyo_katsura"),
        _support.build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    nullify_rule_mod = _find_rule_mod(kashimo, "nullify_field_accuracy")
    if nullify_rule_mod == null:
        return harness.fail_result("kyokyo refresh contract should keep nullify_field_accuracy active after recast")
    if int(nullify_rule_mod.remaining) != 2:
        return harness.fail_result("kyokyo recast should refresh duration back to the full 3-turn window before turn_end decrement")
    return harness.pass_result()
