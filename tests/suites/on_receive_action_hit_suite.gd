extends RefCounted
class_name OnReceiveActionHitSuite

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("on_receive_action_hit_lethal_counter_contract", failures, Callable(self, "_test_on_receive_action_hit_lethal_counter_contract").bind(harness))
    runner.run_test("on_receive_action_hit_ignores_persistent_damage_contract", failures, Callable(self, "_test_on_receive_action_hit_ignores_persistent_damage_contract").bind(harness))

func _test_on_receive_action_hit_lethal_counter_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    _register_receive_counter_resources(content_index)

    var water_skill = SkillDefinitionScript.new()
    water_skill.id = "test_receive_water_skill"
    water_skill.display_name = "Receive Water Skill"
    water_skill.damage_kind = "special"
    water_skill.power = 40
    water_skill.accuracy = 100
    water_skill.mp_cost = 0
    water_skill.priority = 0
    water_skill.targeting = "enemy_active_slot"
    water_skill.combat_type_id = "water"
    content_index.register_resource(water_skill)

    var harmless_skill = SkillDefinitionScript.new()
    harmless_skill.id = "test_receive_harmless"
    harmless_skill.display_name = "Receive Harmless"
    harmless_skill.damage_kind = "none"
    harmless_skill.accuracy = 100
    harmless_skill.mp_cost = 0
    harmless_skill.priority = 0
    harmless_skill.targeting = "self"
    content_index.register_resource(harmless_skill)

    content_index.units["sample_mossaur"].skill_ids[0] = water_skill.id
    content_index.units["sample_tidekit"].skill_ids[0] = harmless_skill.id
    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[0].starting_index = 1
    battle_setup.sides[1].starting_index = 0

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 720, battle_setup)
    var attacker = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if attacker == null or target == null:
        return harness.fail_result("missing active units for on_receive_action_hit lethal contract")
    target.current_hp = 1
    target.current_mp = 20
    target.definition_id = "sample_tidekit"
    content_index.units["sample_tidekit"].passive_skill_id = "test_receive_counter_passive"

    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-B",
            "skill_id": water_skill.id,
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

    if target.current_mp != 5:
        return harness.fail_result("lethal on_receive_action_hit should still apply self mp loss: expected=5 actual=%d" % target.current_mp)
    var expected_counter_damage: int = 30
    var counter_event = _find_counter_damage_event(core.battle_logger.event_log, attacker.unit_instance_id)
    if counter_event == null or counter_event.value_changes.is_empty():
        return harness.fail_result("missing poison counter damage event")
    var actual_counter_damage: int = abs(int(counter_event.value_changes[0].delta))
    if actual_counter_damage != expected_counter_damage:
        return harness.fail_result("poison counter damage mismatch: expected=%d actual=%d" % [expected_counter_damage, actual_counter_damage])
    if not is_equal_approx(float(counter_event.type_effectiveness), 2.0):
        return harness.fail_result("poison counter damage should apply poison effectiveness against wood attacker")
    return harness.pass_result()

func _test_on_receive_action_hit_ignores_persistent_damage_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    _register_receive_counter_resources(content_index)

    var harmless_skill = SkillDefinitionScript.new()
    harmless_skill.id = "test_receive_harmless_persistent"
    harmless_skill.display_name = "Receive Harmless Persistent"
    harmless_skill.damage_kind = "none"
    harmless_skill.accuracy = 100
    harmless_skill.mp_cost = 0
    harmless_skill.priority = 0
    harmless_skill.targeting = "self"
    content_index.register_resource(harmless_skill)

    var water_dot_payload = DamagePayloadScript.new()
    water_dot_payload.payload_type = "damage"
    water_dot_payload.amount = 10
    water_dot_payload.use_formula = false
    water_dot_payload.combat_type_id = "water"
    var water_dot_effect = EffectDefinitionScript.new()
    water_dot_effect.id = "test_receive_water_dot"
    water_dot_effect.display_name = "Receive Water Dot"
    water_dot_effect.scope = "self"
    water_dot_effect.duration_mode = "turns"
    water_dot_effect.duration = 1
    water_dot_effect.decrement_on = "turn_end"
    water_dot_effect.trigger_names = PackedStringArray(["turn_end"])
    water_dot_effect.payloads.append(water_dot_payload)
    content_index.register_resource(water_dot_effect)
    content_index.units["sample_tidekit"].passive_skill_id = "test_receive_counter_passive"

    content_index.units["sample_pyron"].skill_ids[0] = harmless_skill.id
    content_index.units["sample_tidekit"].skill_ids[0] = harmless_skill.id
    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].starting_index = 0

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 721, battle_setup)
    var source_actor = battle_state.get_side("P1").get_active_unit()
    var passive_holder = battle_state.get_side("P2").get_active_unit()
    if source_actor == null or passive_holder == null:
        return harness.fail_result("missing active units for persistent damage contract")
    if core.effect_instance_service.create_instance(
        water_dot_effect,
        passive_holder.unit_instance_id,
        battle_state,
        "test_water_dot_source",
        0,
        source_actor.base_speed,
        {"source_owner_id": source_actor.unit_instance_id}
    ) == null:
        return harness.fail_result("failed to seed water dot effect instance")
    var attacker_hp_before: int = source_actor.current_hp

    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": harmless_skill.id,
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

    if source_actor.current_hp != attacker_hp_before:
        return harness.fail_result("persistent water damage should not trigger on_receive_action_hit counter damage")
    if _find_counter_damage_event(core.battle_logger.event_log, source_actor.unit_instance_id) != null:
        return harness.fail_result("persistent water damage should not emit poison counter damage event")
    return harness.pass_result()

func _register_receive_counter_resources(content_index) -> void:
    if content_index.effects.has("test_receive_leak_self"):
        return
    var self_payload = ResourceModPayloadScript.new()
    self_payload.payload_type = "resource_mod"
    self_payload.resource_key = "mp"
    self_payload.amount = -15
    var self_effect = EffectDefinitionScript.new()
    self_effect.id = "test_receive_leak_self"
    self_effect.display_name = "Receive Leak Self"
    self_effect.scope = "self"
    self_effect.trigger_names = PackedStringArray(["on_receive_action_hit"])
    self_effect.duration_mode = "permanent"
    self_effect.payloads.append(self_payload)
    content_index.register_resource(self_effect)

    var counter_payload = DamagePayloadScript.new()
    counter_payload.payload_type = "damage"
    counter_payload.amount = 15
    counter_payload.use_formula = false
    counter_payload.combat_type_id = "poison"
    var counter_effect = EffectDefinitionScript.new()
    counter_effect.id = "test_receive_leak_counter"
    counter_effect.display_name = "Receive Leak Counter"
    counter_effect.scope = "action_actor"
    counter_effect.trigger_names = PackedStringArray(["on_receive_action_hit"])
    counter_effect.duration_mode = "permanent"
    counter_effect.payloads.append(counter_payload)
    content_index.register_resource(counter_effect)

    var passive = PassiveSkillDefinitionScript.new()
    passive.id = "test_receive_counter_passive"
    passive.display_name = "Receive Counter Passive"
    passive.trigger_names = PackedStringArray(["on_receive_action_hit"])
    passive.effect_ids = PackedStringArray([self_effect.id, counter_effect.id])
    content_index.register_resource(passive)

func _find_counter_damage_event(event_log: Array, target_instance_id: String):
    for ev in event_log:
        if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(ev.target_instance_id) != target_instance_id:
            continue
        if String(ev.payload_summary).find("damage") == -1:
            continue
        if not is_equal_approx(float(ev.type_effectiveness), 2.0) and not is_equal_approx(float(ev.type_effectiveness), 0.5) and not is_equal_approx(float(ev.type_effectiveness), 1.0):
            continue
        return ev
    return null
