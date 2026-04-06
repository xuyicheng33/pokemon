extends "res://tests/suites/multihit_skill_runtime/base.gd"
const BaseSuiteScript := preload("res://tests/suites/multihit_skill_runtime/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("multihit_skill_per_segment_mod_runtime_contract", failures, Callable(self, "_test_multihit_skill_per_segment_mod_runtime_contract").bind(harness))
    runner.run_test("multihit_skill_stops_after_faint_contract", failures, Callable(self, "_test_multihit_skill_stops_after_faint_contract").bind(harness))
    runner.run_test("multihit_skill_top_level_power_ignored_contract", failures, Callable(self, "_test_multihit_skill_top_level_power_ignored_contract").bind(harness))

func _test_multihit_skill_per_segment_mod_runtime_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var skill = _build_multihit_skill(
        "test_multihit_per_segment_skill",
        [
            {"repeat_count": 1, "power": 20, "combat_type_id": "fire", "damage_kind": "special"},
            {"repeat_count": 1, "power": 20, "combat_type_id": "water", "damage_kind": "special"},
        ]
    )
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[1].starting_index = 2
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 840, battle_setup)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if actor == null or target == null:
        return harness.fail_result("missing active units for multihit per-segment contract")

    var incoming_payload = RuleModPayloadScript.new()
    incoming_payload.payload_type = "rule_mod"
    incoming_payload.mod_kind = "incoming_action_final_mod"
    incoming_payload.mod_op = "mul"
    incoming_payload.value = 0.5
    incoming_payload.scope = "self"
    incoming_payload.duration_mode = "turns"
    incoming_payload.duration = 1
    incoming_payload.decrement_on = "turn_end"
    incoming_payload.stacking = "replace"
    incoming_payload.priority = 10
    incoming_payload.required_incoming_command_types = PackedStringArray(["skill"])
    incoming_payload.required_incoming_combat_type_ids = PackedStringArray(["fire"])
    if core.service("rule_mod_service").create_instance(
        incoming_payload,
        {"scope": "unit", "id": target.unit_instance_id},
        battle_state,
        "test_multihit_incoming_mod",
        0,
        target.base_speed
    ) == null:
        return harness.fail_result("failed to create fire-only incoming_action_final_mod")

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
    if damage_events.size() != 2:
        return harness.fail_result("multihit per-segment contract should emit 2 damage events")
    var expected_fire_mul: float = core.service("combat_type_service").calc_effectiveness("fire", target.combat_type_ids)
    var expected_water_mul: float = core.service("combat_type_service").calc_effectiveness("water", target.combat_type_ids)
    var expected_fire_damage: int = _calc_expected_damage(core, battle_state, actor, target, 20, "fire", 0.5)
    var expected_water_damage: int = _calc_expected_damage(core, battle_state, actor, target, 20, "water", 1.0)
    if abs(int(damage_events[0].value_changes[0].delta)) != expected_fire_damage:
        return harness.fail_result("segment 1 damage mismatch: expected=%d actual=%d" % [
            expected_fire_damage,
            abs(int(damage_events[0].value_changes[0].delta)),
        ])
    if abs(int(damage_events[1].value_changes[0].delta)) != expected_water_damage:
        return harness.fail_result("segment 2 damage mismatch: expected=%d actual=%d" % [
            expected_water_damage,
            abs(int(damage_events[1].value_changes[0].delta)),
        ])
    if not is_equal_approx(float(damage_events[0].type_effectiveness), expected_fire_mul):
        return harness.fail_result("segment 1 should log raw fire type effectiveness")
    if not is_equal_approx(float(damage_events[1].type_effectiveness), expected_water_mul):
        return harness.fail_result("segment 2 should log raw water type effectiveness")
    if String(damage_events[0].payload_summary).find("segment 1/2") == -1 or String(damage_events[1].payload_summary).find("segment 2/2") == -1:
        return harness.fail_result("multihit damage logs should carry segment indices")
    return harness.pass_result()

func _test_multihit_skill_stops_after_faint_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var skill = _build_multihit_skill(
        "test_multihit_stop_skill",
        [
            {"repeat_count": 3, "power": 18, "combat_type_id": "fire", "damage_kind": "special"},
        ]
    )
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[1].starting_index = 2
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 841, battle_setup)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if actor == null or target == null:
        return harness.fail_result("missing active units for multihit faint-stop contract")
    target.current_hp = 1

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
        return harness.fail_result("multihit should stop emitting damage after target faints")
    if String(damage_events[0].payload_summary).find("segment 1/3") == -1:
        return harness.fail_result("faint-stop contract should only keep the first segment log")
    return harness.pass_result()

func _test_multihit_skill_top_level_power_ignored_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var skill = _build_multihit_skill(
        "test_multihit_top_level_power_ignored_skill",
        [{"repeat_count": 1, "power": 20, "combat_type_id": "fire", "damage_kind": "special"}]
    )
    skill.power = 999
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[1].starting_index = 2
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 842, battle_setup)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if actor == null or target == null:
        return harness.fail_result("missing active units for top-level power ignore contract")

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
        return harness.fail_result("segmented skill should emit exactly one segment damage event in top-level power ignore probe")
    var expected_damage: int = _calc_expected_damage(core, battle_state, actor, target, 20, "fire", 1.0)
    var actual_damage: int = abs(int(damage_events[0].value_changes[0].delta))
    if actual_damage != expected_damage:
        return harness.fail_result("segmented skill damage should use segment power, not top-level power: expected=%d actual=%d" % [expected_damage, actual_damage])
    if String(damage_events[0].payload_summary).find("segment 1/1") == -1:
        return harness.fail_result("segmented skill damage log should still preserve the segment 1/1 marker")
    return harness.pass_result()
