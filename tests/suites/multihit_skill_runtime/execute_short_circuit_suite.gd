extends "res://tests/suites/multihit_skill_runtime/base.gd"
const BaseSuiteScript := preload("res://tests/suites/multihit_skill_runtime/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("multihit_skill_execute_short_circuit_contract", failures, Callable(self, "_test_multihit_skill_execute_short_circuit_contract").bind(harness))

func _test_multihit_skill_execute_short_circuit_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var skill = _build_multihit_skill(
        "test_multihit_execute_skill",
        [
            {"repeat_count": 2, "power": 12, "combat_type_id": "dark", "damage_kind": "special"},
            {"repeat_count": 2, "power": 12, "combat_type_id": "light", "damage_kind": "special"},
        ]
    )
    skill.execute_target_hp_ratio_lte = 1.0
    skill.execute_required_total_stacks = 0
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var on_segment_effect = _build_mp_loss_effect("test_multihit_execute_segment_listener", "on_receive_action_damage_segment", -1)
    content_index.register_resource(on_segment_effect)

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 844)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if actor == null or target == null:
        return harness.fail_result("missing active units for multihit execute short-circuit contract")
    var before_mp: int = int(target.current_mp)
    if core.service("effect_instance_service").create_instance(on_segment_effect, target.unit_instance_id, battle_state, "test_multihit_execute_segment", 0, target.base_speed) == null:
        return harness.fail_result("failed to seed execute short-circuit segment listener")

    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": actor.public_id,
            "skill_id": skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": target.public_id,
        }),
    ])

    var damage_events := _collect_actor_damage_events(core.service("battle_logger").event_log, actor.public_id)
    if damage_events.size() != 1:
        return harness.fail_result("execute short-circuit should emit exactly 1 damage event")
    if String(damage_events[0].payload_summary).find("[execute]") == -1:
        return harness.fail_result("execute short-circuit should keep execute marker in public damage log")
    if String(damage_events[0].payload_summary).find("segment ") != -1:
        return harness.fail_result("execute short-circuit should not expose multihit segment logs")
    if int(target.current_mp) != before_mp:
        return harness.fail_result("execute short-circuit should skip on_receive_action_damage_segment triggers")
    return harness.pass_result()
