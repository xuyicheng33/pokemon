extends "res://tests/suites/kashimo_runtime/base.gd"
const BaseSuiteScript := preload("res://tests/suites/kashimo_runtime/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("kashimo_kyokyo_katsura_refresh_contract", failures, Callable(self, "_test_kashimo_kyokyo_katsura_refresh_contract").bind(harness))

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
