extends RefCounted
class_name MultihitSkillRuntimeSuite

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("multihit_skill_per_segment_mod_runtime_contract", failures, Callable(self, "_test_multihit_skill_per_segment_mod_runtime_contract").bind(harness))
    runner.run_test("multihit_skill_stops_after_faint_contract", failures, Callable(self, "_test_multihit_skill_stops_after_faint_contract").bind(harness))
    runner.run_test("multihit_skill_segment_trigger_contract", failures, Callable(self, "_test_multihit_skill_segment_trigger_contract").bind(harness))
    runner.run_test("multihit_skill_validation_contract", failures, Callable(self, "_test_multihit_skill_validation_contract").bind(harness))

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

func _test_multihit_skill_validation_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var bad_skill = SkillDefinitionScript.new()
    bad_skill.id = "test_bad_multihit_skill"
    bad_skill.display_name = "Bad Multihit Skill"
    bad_skill.damage_kind = "special"
    bad_skill.power = 20
    bad_skill.accuracy = 100
    bad_skill.mp_cost = 0
    bad_skill.priority = 0
    bad_skill.targeting = "enemy_active_slot"
    var bad_segment = SkillDamageSegmentScript.new()
    bad_segment.repeat_count = 0
    bad_segment.power = 20
    bad_segment.damage_kind = "special"
    bad_segment.combat_type_id = "missing_combat_type"
    var bad_segments: Array[Resource] = [bad_segment]
    bad_skill.damage_segments = bad_segments
    content_index.register_resource(bad_skill)

    var errors: Array = content_index.validate_snapshot()
    if not _has_error(errors, "skill[test_bad_multihit_skill].damage_segments[0].repeat_count must be > 0, got 0"):
        return harness.fail_result("multihit validation should reject non-positive repeat_count")
    if not _has_error(errors, "skill[test_bad_multihit_skill].damage_segments[0].combat_type_id missing combat type: missing_combat_type"):
        return harness.fail_result("multihit validation should reject missing segment combat type")
    return harness.pass_result()

func _build_multihit_skill(skill_id: String, segments: Array):
    var skill = SkillDefinitionScript.new()
    skill.id = skill_id
    skill.display_name = skill_id
    skill.damage_kind = "special"
    skill.power = 40
    skill.accuracy = 100
    skill.mp_cost = 0
    skill.priority = 0
    skill.targeting = "enemy_active_slot"
    var built_segments: Array[Resource] = []
    for segment_data in segments:
        var segment = SkillDamageSegmentScript.new()
        segment.repeat_count = int(segment_data.get("repeat_count", 1))
        segment.power = int(segment_data.get("power", 0))
        segment.combat_type_id = String(segment_data.get("combat_type_id", ""))
        segment.damage_kind = String(segment_data.get("damage_kind", "special"))
        built_segments.append(segment)
    skill.damage_segments = built_segments
    return skill

func _build_mp_loss_effect(effect_id: String, trigger_name: String, mp_delta: int):
    var effect = EffectDefinitionScript.new()
    effect.id = effect_id
    effect.display_name = effect_id
    effect.scope = "self"
    effect.duration_mode = "permanent"
    effect.trigger_names = PackedStringArray([trigger_name])
    var payload = ResourceModPayloadScript.new()
    payload.payload_type = "resource_mod"
    payload.resource_key = "mp"
    payload.amount = mp_delta
    effect.payloads.append(payload)
    return effect

func _collect_actor_damage_events(event_log: Array, actor_public_id: String) -> Array:
    var matched: Array = []
    for log_event in event_log:
        if log_event.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(log_event.payload_summary).begins_with("%s dealt " % actor_public_id):
            matched.append(log_event)
    return matched

func _calc_expected_damage(core, battle_state, actor, target, power: int, combat_type_id: String, incoming_multiplier: float) -> int:
    var type_effectiveness: float = core.service("combat_type_service").calc_effectiveness(combat_type_id, target.combat_type_ids)
    return core.service("damage_service").apply_final_mod(
        core.service("damage_service").calc_base_damage(
            battle_state.battle_level,
            power,
            actor.base_sp_attack,
            target.base_sp_defense
        ),
        incoming_multiplier * type_effectiveness
    )

func _has_error(errors: Array, expected_error: String) -> bool:
    for error_message in errors:
        if String(error_message) == expected_error:
            return true
    return false
