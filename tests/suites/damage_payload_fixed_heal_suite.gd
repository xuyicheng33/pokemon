extends RefCounted
class_name DamagePayloadFixedHealSuite

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const DamagePayloadContractTestHelperScript := preload("res://tests/support/damage_payload_contract_test_helper.gd")

var _helper = DamagePayloadContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("damage_payload_fixed_type_resolution", failures, Callable(self, "_test_fixed_type_resolution").bind(harness))
    runner.run_test("heal_payload_percent_resolution", failures, Callable(self, "_test_heal_percent_resolution").bind(harness))
func _test_fixed_type_resolution(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())

    var payload = DamagePayloadScript.new()
    payload.payload_type = "damage"
    payload.amount = 20
    payload.use_formula = false
    payload.combat_type_id = "fire"
    var effect = EffectDefinitionScript.new()
    effect.id = "test_fixed_type_resolution_effect"
    effect.display_name = "Fixed Type Resolution"
    effect.scope = "target"
    effect.trigger_names = PackedStringArray(["on_cast"])
    effect.duration_mode = "permanent"
    effect.payloads.clear()
    effect.payloads.append(payload)
    content_index.register_resource(effect)

    var skill = SkillDefinitionScript.new()
    skill.id = "test_fixed_type_resolution_skill"
    skill.display_name = "Fixed Type Resolution Skill"
    skill.damage_kind = "none"
    skill.accuracy = 100
    skill.mp_cost = 0
    skill.priority = 0
    skill.targeting = "enemy_active_slot"
    skill.effects_on_cast_ids = PackedStringArray([effect.id])
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var harmless_skill = SkillDefinitionScript.new()
    harmless_skill.id = "test_harmless_wait_fixed"
    harmless_skill.display_name = "Harmless Wait Fixed"
    harmless_skill.damage_kind = "none"
    harmless_skill.accuracy = 100
    harmless_skill.mp_cost = 0
    harmless_skill.priority = 0
    harmless_skill.targeting = "self"
    content_index.register_resource(harmless_skill)
    content_index.units["sample_tidekit"].skill_ids[0] = harmless_skill.id

    var battle_setup = sample_factory.build_sample_setup()
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 610)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": harmless_skill.id,
        }),
    ])
    var effect_damage_event = _find_effect_damage_event(core.battle_logger.event_log)
    if effect_damage_event == null or effect_damage_event.value_changes.is_empty():
        return harness.fail_result("missing fixed damage event")
    if abs(int(effect_damage_event.value_changes[0].delta)) != 10:
        return harness.fail_result("fixed fire damage against water should be halved to 10")
    if not is_equal_approx(float(effect_damage_event.type_effectiveness), 0.5):
        return harness.fail_result("fixed damage should apply fire type effectiveness")
    return harness.pass_result()

func _test_heal_percent_resolution(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())

    var heal_payload = HealPayloadScript.new()
    heal_payload.payload_type = "heal"
    heal_payload.use_percent = true
    heal_payload.percent = 25
    var heal_effect = EffectDefinitionScript.new()
    heal_effect.id = "test_heal_percent_effect"
    heal_effect.display_name = "Heal Percent Effect"
    heal_effect.scope = "self"
    heal_effect.trigger_names = PackedStringArray(["on_cast"])
    heal_effect.duration_mode = "permanent"
    heal_effect.payloads.clear()
    heal_effect.payloads.append(heal_payload)
    content_index.register_resource(heal_effect)

    var heal_skill = SkillDefinitionScript.new()
    heal_skill.id = "test_heal_percent_skill"
    heal_skill.display_name = "Heal Percent Skill"
    heal_skill.damage_kind = "none"
    heal_skill.accuracy = 100
    heal_skill.mp_cost = 0
    heal_skill.priority = 0
    heal_skill.targeting = "self"
    heal_skill.effects_on_cast_ids = PackedStringArray([heal_effect.id])
    content_index.register_resource(heal_skill)
    content_index.units["sample_pyron"].skill_ids[0] = heal_skill.id

    var harmless_skill = SkillDefinitionScript.new()
    harmless_skill.id = "test_harmless_wait_heal"
    harmless_skill.display_name = "Harmless Wait Heal"
    harmless_skill.damage_kind = "none"
    harmless_skill.accuracy = 100
    harmless_skill.mp_cost = 0
    harmless_skill.priority = 0
    harmless_skill.targeting = "self"
    content_index.register_resource(harmless_skill)
    content_index.units["sample_tidekit"].skill_ids[0] = harmless_skill.id

    var battle_setup = sample_factory.build_sample_setup()
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 611)
    var actor = battle_state.get_side("P1").get_active_unit()
    actor.current_hp = max(1, int(floor(float(actor.max_hp) / 2.0)))
    var expected_gain = min(actor.max_hp - actor.current_hp, max(1, int(floor(float(actor.max_hp) * 0.25))))
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": heal_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": harmless_skill.id,
        }),
    ])
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_HEAL and not log_event.value_changes.is_empty():
            if int(log_event.value_changes[0].delta) != expected_gain:
                return harness.fail_result("heal percent delta mismatch")
            return harness.pass_result()
    return harness.fail_result("missing heal percent event")


func _build_initialized_battle(core, content_index, battle_setup, seed: int):
    return _helper._build_initialized_battle(core, content_index, battle_setup, seed)

func _find_effect_damage_event(event_log: Array):
    return _helper._find_effect_damage_event(event_log)
