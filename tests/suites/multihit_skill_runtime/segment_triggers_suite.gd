extends "res://tests/suites/multihit_skill_runtime/base.gd"
const BaseSuiteScript := preload("res://tests/suites/multihit_skill_runtime/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("multihit_skill_segment_trigger_contract", failures, Callable(self, "_test_multihit_skill_segment_trigger_contract").bind(harness))
    runner.run_test("multihit_skill_segment_context_restore_contract", failures, Callable(self, "_test_multihit_skill_segment_context_restore_contract").bind(harness))

func _test_multihit_skill_segment_trigger_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var skill = _build_multihit_skill(
        "test_multihit_trigger_skill",
        [
            {"repeat_count": 3, "power": 10, "combat_type_id": "", "damage_kind": "special"},
        ]
    )
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var on_hit_effect = _build_mp_loss_effect("test_multihit_receive_once", "on_receive_action_hit", -5)
    var on_segment_effect = _build_mp_loss_effect("test_multihit_receive_segment", "on_receive_action_damage_segment", -1)
    content_index.register_resource(on_hit_effect)
    content_index.register_resource(on_segment_effect)

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 842)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if actor == null or target == null:
        return harness.fail_result("missing active units for multihit trigger contract")
    var before_mp: int = int(target.current_mp)
    if core.service("effect_instance_service").create_instance(on_hit_effect, target.unit_instance_id, battle_state, "test_receive_once", 0, target.base_speed) == null:
        return harness.fail_result("failed to seed on_receive_action_hit effect instance")
    if core.service("effect_instance_service").create_instance(on_segment_effect, target.unit_instance_id, battle_state, "test_receive_segment", 0, target.base_speed) == null:
        return harness.fail_result("failed to seed on_receive_action_damage_segment effect instance")

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

    if before_mp - int(target.current_mp) != 8:
        return harness.fail_result("multihit should trigger on_receive_action_hit once and segment trigger three times")
    return harness.pass_result()

func _test_multihit_skill_segment_context_restore_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var skill = _build_multihit_skill(
        "test_multihit_context_restore_skill",
        [
            {"repeat_count": 1, "power": 12, "combat_type_id": "fire", "damage_kind": "special"},
            {"repeat_count": 1, "power": 12, "combat_type_id": "water", "damage_kind": "special"},
        ]
    )
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var filtered_on_hit_effect = _build_filtered_on_hit_mp_loss_effect(
        "test_multihit_on_hit_water_filter",
        "water",
        -7
    )
    content_index.register_resource(filtered_on_hit_effect)

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 843)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if actor == null or target == null:
        return harness.fail_result("missing active units for multihit context-restore contract")
    var before_mp: int = int(target.current_mp)
    if core.service("effect_instance_service").create_instance(filtered_on_hit_effect, target.unit_instance_id, battle_state, "test_multihit_on_hit_filter", 0, target.base_speed) == null:
        return harness.fail_result("failed to seed on_receive_action_hit filter effect instance")

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

    if int(target.current_mp) != before_mp:
        return harness.fail_result("multihit should restore action_combat_type_id before on_receive_action_hit filters run")
    return harness.pass_result()
