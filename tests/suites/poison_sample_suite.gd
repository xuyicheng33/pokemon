extends RefCounted
class_name PoisonSampleSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("poison_sample_fixed_damage_type_effectiveness_contract", failures, Callable(self, "_test_poison_sample_fixed_damage_type_effectiveness_contract").bind(harness))

func _test_poison_sample_fixed_damage_type_effectiveness_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var content_index_a = harness.build_loaded_content_index(sample_factory)
    if content_index_a.skills.get("sample_poison_sting", null) == null:
        return harness.fail_result("missing sample_poison_sting skill content")
    if content_index_a.effects.get("sample_poison_sting_burst", null) == null:
        return harness.fail_result("missing sample_poison_sting_burst effect content")
    content_index_a.units["sample_pyron"].skill_ids[0] = "sample_poison_sting"
    var state_a = harness.build_initialized_battle(core, content_index_a, sample_factory, 3101, sample_factory.build_sample_setup())
    var attacker_a = state_a.get_side("P1").get_active_unit()
    var target_a = state_a.get_side("P2").get_active_unit()
    if attacker_a == null or target_a == null:
        return harness.fail_result("missing active units for poison sample case A")
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(state_a, content_index_a, [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_poison_sting",
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    var expected_mul_a: float = core.service("combat_type_service").calc_effectiveness("poison", target_a.combat_type_ids)
    if not is_equal_approx(expected_mul_a, 2.0):
        return harness.fail_result("poison -> water baseline should be 2.0, got %s" % var_to_str(expected_mul_a))
    var expected_damage_a: int = core.service("damage_service").apply_final_mod(15, expected_mul_a)
    var actual_damage_a: Dictionary = _extract_single_poison_burst_damage(core.service("battle_logger").event_log, target_a.unit_instance_id)
    if actual_damage_a.has("error"):
        return harness.fail_result(str(actual_damage_a["error"]))
    if not is_equal_approx(float(actual_damage_a["type_effectiveness"]), expected_mul_a):
        return harness.fail_result("poison sample type_effectiveness mismatch: expected=%s actual=%s" % [
            var_to_str(expected_mul_a),
            var_to_str(actual_damage_a["type_effectiveness"]),
        ])
    if int(actual_damage_a["damage"]) != expected_damage_a:
        return harness.fail_result("poison sample damage mismatch (water): expected=%d actual=%d" % [
            expected_damage_a,
            int(actual_damage_a["damage"]),
        ])

    var content_index_b = harness.build_loaded_content_index(sample_factory)
    content_index_b.units["sample_pyron"].skill_ids[0] = "sample_poison_sting"
    content_index_b.units["sample_tidekit"].combat_type_ids = PackedStringArray(["steel"])
    var state_b = harness.build_initialized_battle(core, content_index_b, sample_factory, 3102, sample_factory.build_sample_setup())
    var target_b = state_b.get_side("P2").get_active_unit()
    if target_b == null:
        return harness.fail_result("missing target unit for poison sample case B")
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(state_b, content_index_b, [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_poison_sting",
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    var expected_mul_b: float = core.service("combat_type_service").calc_effectiveness("poison", target_b.combat_type_ids)
    if not is_equal_approx(expected_mul_b, 0.5):
        return harness.fail_result("poison -> steel baseline should be 0.5, got %s" % var_to_str(expected_mul_b))
    var expected_damage_b: int = core.service("damage_service").apply_final_mod(15, expected_mul_b)
    var actual_damage_b: Dictionary = _extract_single_poison_burst_damage(core.service("battle_logger").event_log, target_b.unit_instance_id)
    if actual_damage_b.has("error"):
        return harness.fail_result(str(actual_damage_b["error"]))
    if not is_equal_approx(float(actual_damage_b["type_effectiveness"]), expected_mul_b):
        return harness.fail_result("poison sample type_effectiveness mismatch (steel): expected=%s actual=%s" % [
            var_to_str(expected_mul_b),
            var_to_str(actual_damage_b["type_effectiveness"]),
        ])
    if int(actual_damage_b["damage"]) != expected_damage_b:
        return harness.fail_result("poison sample damage mismatch (steel): expected=%d actual=%d" % [
            expected_damage_b,
            int(actual_damage_b["damage"]),
        ])
    return harness.pass_result()

func _extract_single_poison_burst_damage(event_log: Array, target_unit_id: String) -> Dictionary:
    var matched: Array = []
    for ev in event_log:
        if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(ev.target_instance_id) != String(target_unit_id):
            continue
        if String(ev.trigger_name) != "on_hit":
            continue
        if String(ev.payload_summary).find("damage") == -1:
            continue
        if ev.value_changes.is_empty():
            continue
        matched.append(ev)
    if matched.size() != 1:
        return {"error": "expected exactly one poison burst EFFECT_DAMAGE, got %d" % matched.size()}
    var ev = matched[0]
    return {
        "damage": abs(int(ev.value_changes[0].delta)),
        "type_effectiveness": float(ev.type_effectiveness),
    }

