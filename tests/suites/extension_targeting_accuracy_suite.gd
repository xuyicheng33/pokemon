extends RefCounted
class_name ExtensionTargetingAccuracySuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("required_target_effects_contract", failures, Callable(self, "_test_required_target_effects_contract").bind(harness))
    runner.run_test("incoming_accuracy_contract", failures, Callable(self, "_test_incoming_accuracy_contract").bind(harness))
func _test_required_target_effects_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var marker_effect = EffectDefinitionScript.new()
    marker_effect.id = "test_required_runtime_marker"
    marker_effect.display_name = "Required Runtime Marker"
    marker_effect.scope = "self"
    marker_effect.duration_mode = "turns"
    marker_effect.duration = 2
    marker_effect.decrement_on = "turn_end"
    marker_effect.stacking = "replace"
    content_index.register_resource(marker_effect)

    var stat_payload = StatModPayloadScript.new()
    stat_payload.payload_type = "stat_mod"
    stat_payload.stat_name = "speed"
    stat_payload.stage_delta = -1
    var conditional_effect = EffectDefinitionScript.new()
    conditional_effect.id = "test_required_conditional_effect"
    conditional_effect.display_name = "Required Conditional Effect"
    conditional_effect.scope = "target"
    conditional_effect.trigger_names = PackedStringArray(["on_hit"])
    conditional_effect.required_target_effects = PackedStringArray([marker_effect.id])
    conditional_effect.payloads.append(stat_payload)
    content_index.register_resource(conditional_effect)

    var conditional_skill = SkillDefinitionScript.new()
    conditional_skill.id = "test_required_conditional_skill"
    conditional_skill.display_name = "Required Conditional Skill"
    conditional_skill.damage_kind = "none"
    conditional_skill.power = 0
    conditional_skill.accuracy = 100
    conditional_skill.mp_cost = 0
    conditional_skill.priority = 0
    conditional_skill.targeting = "enemy_active_slot"
    conditional_skill.effects_on_hit_ids = PackedStringArray([conditional_effect.id])
    content_index.register_resource(conditional_skill)

    var skipped_state = harness.build_initialized_battle(core, content_index, sample_factory, 907)
    var skipped_p1 = skipped_state.get_side("P1").get_active_unit()
    var skipped_p2 = skipped_state.get_side("P2").get_active_unit()
    skipped_p1.regular_skill_ids[0] = conditional_skill.id
    skipped_p1.base_speed = 999
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(skipped_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": conditional_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if int(skipped_p2.stat_stages.get("speed", 0)) != 0:
        return harness.fail_result("required_target_effects should skip payloads when target marker is missing")
    if _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.EFFECT_STAT_MOD \
            and ev.target_instance_id == skipped_p2.unit_instance_id
    ):
        return harness.fail_result("required_target_effects skip path must not emit payload logs")

    var applied_state = harness.build_initialized_battle(core, content_index, sample_factory, 908)
    var applied_p1 = applied_state.get_side("P1").get_active_unit()
    var applied_p2 = applied_state.get_side("P2").get_active_unit()
    applied_p1.regular_skill_ids[0] = conditional_skill.id
    applied_p1.base_speed = 999
    core.effect_instance_service.create_instance(marker_effect, applied_p2.unit_instance_id, applied_state, "test_required_runtime_marker_source", 0, applied_p2.base_speed)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(applied_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": conditional_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if int(applied_p2.stat_stages.get("speed", 0)) != -1:
        return harness.fail_result("required_target_effects should allow payloads once target marker exists")
    return harness.pass_result()

func _test_incoming_accuracy_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 909)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    if p1_active == null or p2_active == null:
        return harness.fail_result("missing active units for incoming_accuracy contract")

    var incoming_payload = RuleModPayloadScript.new()
    incoming_payload.payload_type = "rule_mod"
    incoming_payload.mod_kind = "incoming_accuracy"
    incoming_payload.mod_op = "add"
    incoming_payload.value = -10
    incoming_payload.scope = "self"
    incoming_payload.duration_mode = "permanent"
    incoming_payload.decrement_on = "turn_end"
    incoming_payload.stacking = "none"
    if core.rule_mod_service.create_instance(incoming_payload, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "test_incoming_accuracy_down", 0, p2_active.base_speed) == null:
        return harness.fail_result("failed to create incoming_accuracy rule_mod")

    var accuracy_skill = SkillDefinitionScript.new()
    accuracy_skill.id = "test_incoming_accuracy_skill"
    accuracy_skill.display_name = "Incoming Accuracy Skill"
    accuracy_skill.damage_kind = "none"
    accuracy_skill.power = 0
    accuracy_skill.accuracy = 95
    accuracy_skill.mp_cost = 0
    accuracy_skill.priority = 0
    accuracy_skill.targeting = "enemy_active_slot"
    content_index.register_resource(accuracy_skill)

    var command = core.command_builder.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": accuracy_skill.id,
    })
    command.actor_id = p1_active.unit_instance_id
    var hit_info = core.action_cast_service.resolve_hit(command, accuracy_skill, p2_active, battle_state, content_index)
    if abs(float(hit_info.get("hit_rate", -1.0)) - 0.85) > 0.0001:
        return harness.fail_result("incoming_accuracy should reduce 95 accuracy enemy_active skill to 85")

    accuracy_skill.accuracy = 100
    var guaranteed_hit_info = core.action_cast_service.resolve_hit(command, accuracy_skill, p2_active, battle_state, content_index)
    if guaranteed_hit_info.get("hit_roll", "not-null") != null or abs(float(guaranteed_hit_info.get("hit_rate", -1.0)) - 1.0) > 0.0001:
        return harness.fail_result("incoming_accuracy must not affect guaranteed-hit actions")

    accuracy_skill.accuracy = 95
    accuracy_skill.targeting = "self"
    var self_target_hit_info = core.action_cast_service.resolve_hit(command, accuracy_skill, p1_active, battle_state, content_index)
    if abs(float(self_target_hit_info.get("hit_rate", -1.0)) - 0.95) > 0.0001:
        return harness.fail_result("incoming_accuracy must not affect self-target actions")
    return harness.pass_result()


func _has_event(event_log: Array, predicate: Callable) -> bool:
    for log_event in event_log:
        if predicate.call(log_event):
            return true
    return false
