extends RefCounted
class_name ObitoUltimateSuite

const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("obito_shiwei_weishouyu_segment_order_contract", failures, Callable(self, "_test_obito_shiwei_weishouyu_segment_order_contract").bind(harness))
    runner.run_test("obito_shiwei_weishouyu_segment_damage_log_contract", failures, Callable(self, "_test_obito_shiwei_weishouyu_segment_damage_log_contract").bind(harness))

func _test_obito_shiwei_weishouyu_segment_order_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var ultimate = content_index.skills.get("obito_shiwei_weishouyu", null)
    if ultimate == null:
        return harness.fail_result("missing obito ultimate definition")
    if ultimate.damage_segments.size() != 2:
        return harness.fail_result("obito ultimate should define exactly 2 segment resources")
    var dark_segment = ultimate.damage_segments[0]
    var light_segment = ultimate.damage_segments[1]
    if int(dark_segment.repeat_count) != 2 or int(dark_segment.power) != 12 or String(dark_segment.combat_type_id) != "dark":
        return harness.fail_result("obito ultimate first segment resource should be 2x dark power 12")
    if int(light_segment.repeat_count) != 8 or int(light_segment.power) != 12 or String(light_segment.combat_type_id) != "light":
        return harness.fail_result("obito ultimate second segment resource should be 8x light power 12")
    return harness.pass_result()

func _test_obito_shiwei_weishouyu_segment_damage_log_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_mirror_setup(sample_factory), 1540)
    var obito = battle_state.get_side("P1").get_active_unit()
    if obito == null:
        return harness.fail_result("missing obito active unit for ultimate segment log contract")
    obito.ultimate_points = 3
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "obito_shiwei_weishouyu"),
        _support.build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var damage_events = _support.collect_actor_damage_events(core.service("battle_logger").event_log, "P1-A")
    if damage_events.size() != 10:
        return harness.fail_result("obito ultimate should emit 10 damage events")
    for segment_index in range(10):
        var expected_marker := "segment %d/10" % [segment_index + 1]
        if String(damage_events[segment_index].payload_summary).find(expected_marker) == -1:
            return harness.fail_result("obito ultimate damage log missing %s marker" % expected_marker)
        var expected_mul := 0.5 if segment_index < 2 else 2.0
        if not is_equal_approx(float(damage_events[segment_index].type_effectiveness), expected_mul):
            return harness.fail_result("obito ultimate segment %d should have type_effectiveness=%s" % [segment_index + 1, var_to_str(expected_mul)])
    return harness.pass_result()
