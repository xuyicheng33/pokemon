extends RefCounted
class_name CombatTypeRuntimeSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const CombatTypeTestHelperScript := preload("res://tests/support/combat_type_test_helper.gd")

var _helper = CombatTypeTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("combat_type_direct_damage_and_logs", failures, Callable(self, "_test_combat_type_direct_damage_and_logs").bind(harness))
    runner.run_test("combat_type_formula_damage_paths", failures, Callable(self, "_test_combat_type_formula_damage_paths").bind(harness))
    runner.run_test("combat_type_default_and_recoil_paths", failures, Callable(self, "_test_combat_type_default_and_recoil_paths").bind(harness))
    runner.run_test("recoil_ratio_runtime_config_contract", failures, Callable(self, "_test_recoil_ratio_runtime_config_contract").bind(harness))
func _test_combat_type_direct_damage_and_logs(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var neutral_result = _run_direct_damage_case(harness, core, sample_factory, "", null)
    if neutral_result.has("error"):
        return harness.fail_result(str(neutral_result["error"]))
    if not is_equal_approx(float(neutral_result["type_effectiveness"]), 1.0):
        return harness.fail_result("neutral direct damage should log type_effectiveness = 1.0")

    var typed_result = _run_direct_damage_case(harness, core, sample_factory, "fire", null)
    if typed_result.has("error"):
        return harness.fail_result(str(typed_result["error"]))
    if not is_equal_approx(float(typed_result["type_effectiveness"]), 2.0):
        return harness.fail_result("typed direct damage should log type_effectiveness = 2.0")
    if int(typed_result["damage"]) <= int(neutral_result["damage"]):
        return harness.fail_result("typed direct damage should exceed neutral baseline")

    var modded_result = _run_direct_damage_case(harness, core, sample_factory, "fire", 1.5)
    if modded_result.has("error"):
        return harness.fail_result(str(modded_result["error"]))
    if not is_equal_approx(float(modded_result["type_effectiveness"]), 2.0):
        return harness.fail_result("rule_mod case should still log raw type_effectiveness = 2.0")
    if int(modded_result["damage"]) <= int(typed_result["damage"]):
        return harness.fail_result("rule_mod should stack on top of type effectiveness")

    return harness.pass_result()

func _test_combat_type_formula_damage_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var inheritance_result = _run_formula_skill_case(harness, core, sample_factory)
    if inheritance_result.has("error"):
        return harness.fail_result(str(inheritance_result["error"]))
    if not is_equal_approx(float(inheritance_result["type_effectiveness"]), 2.0):
        return harness.fail_result("formula damage in skill chain should inherit skill combat_type")

    var passive_result = _run_non_skill_formula_case(harness, core, sample_factory)
    if passive_result.has("error"):
        return harness.fail_result(str(passive_result["error"]))
    if not is_equal_approx(float(passive_result["type_effectiveness"]), 1.0):
        return harness.fail_result("non-skill formula damage should stay neutral")

    return harness.pass_result()

func _test_combat_type_default_and_recoil_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = harness.build_sample_setup(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 641)

    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p1_active.current_mp = 0
    p1_active.regen_per_turn = 0
    p2_active.current_mp = 0
    p2_active.regen_per_turn = 0
    for bench_unit_id in battle_state.get_side("P1").bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    for bench_unit_id in battle_state.get_side("P2").bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0

    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [])

    var default_damage_found: bool = false
    var recoil_damage_found: bool = false
    for ev in core.service("battle_logger").event_log:
        if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(ev.payload_summary).find("dealt") != -1:
            if not is_equal_approx(float(ev.type_effectiveness), 1.0):
                return harness.fail_result("default action damage should log neutral type_effectiveness")
            default_damage_found = true
        if String(ev.payload_summary).find("recoil") != -1:
            if not is_equal_approx(float(ev.type_effectiveness), 1.0):
                return harness.fail_result("recoil damage should log neutral type_effectiveness")
            recoil_damage_found = true
    if not default_damage_found:
        return harness.fail_result("missing default action damage log")
    if not recoil_damage_found:
        return harness.fail_result("missing recoil damage log")
    return harness.pass_result()

func _test_recoil_ratio_runtime_config_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var format_config = content_index.battle_formats.get("prototype_full_open", null)
    if format_config == null:
        return harness.fail_result("missing sample battle format")
    format_config.default_recoil_ratio = 0.5
    var battle_setup = harness.build_sample_setup(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 642)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p1_active.current_mp = 0
    p1_active.regen_per_turn = 0
    p2_active.current_mp = 0
    p2_active.regen_per_turn = 0
    for bench_unit_id in battle_state.get_side("P1").bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    for bench_unit_id in battle_state.get_side("P2").bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
    var actual_recoil: int = -1
    for ev in core.service("battle_logger").event_log:
        if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if ev.target_instance_id != p1_active.unit_instance_id:
            continue
        if String(ev.payload_summary).find("recoil") == -1:
            continue
        if ev.value_changes.is_empty():
            return harness.fail_result("recoil log should carry hp value_change")
        actual_recoil = abs(int(ev.value_changes[0].delta))
        break
    if actual_recoil < 0:
        return harness.fail_result("missing recoil damage log for configured-ratio default action")
    var expected_recoil: int = max(1, int(floor(float(p1_active.max_hp) * 0.5)))
    if actual_recoil != expected_recoil:
        return harness.fail_result("default recoil should read runtime-configured ratio: expected=%d actual=%d" % [expected_recoil, actual_recoil])
    return harness.pass_result()

func _run_direct_damage_case(harness, core, sample_factory, skill_type_id: String, final_mod: Variant) -> Dictionary:
    return _helper.run_direct_damage_case(harness, core, sample_factory, skill_type_id, final_mod)

func _run_formula_skill_case(harness, core, sample_factory) -> Dictionary:
    return _helper.run_formula_skill_case(harness, core, sample_factory)

func _run_non_skill_formula_case(harness, core, sample_factory) -> Dictionary:
    return _helper.run_non_skill_formula_case(harness, core, sample_factory)

func _build_initialized_battle(core, content_index, battle_setup, seed: int):
    return _helper.build_initialized_battle(core, content_index, battle_setup, seed)
