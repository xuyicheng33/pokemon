extends RefCounted
class_name DamagePayloadContractSuite

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("damage_payload_formula_kind_validation", failures, Callable(self, "_test_formula_damage_kind_validation").bind(harness))
    runner.run_test("damage_payload_formula_kind_resolution", failures, Callable(self, "_test_formula_damage_kind_resolution").bind(harness))
    runner.run_test("damage_payload_fixed_type_validation", failures, Callable(self, "_test_fixed_type_validation").bind(harness))
    runner.run_test("damage_payload_fixed_type_resolution", failures, Callable(self, "_test_fixed_type_resolution").bind(harness))
    runner.run_test("heal_payload_percent_resolution", failures, Callable(self, "_test_heal_percent_resolution").bind(harness))

func _test_formula_damage_kind_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var payload = DamagePayloadScript.new()
        payload.payload_type = "damage"
        payload.amount = 20
        payload.use_formula = true
        payload.damage_kind = "none"
        var effect = EffectDefinitionScript.new()
        effect.id = "test_invalid_formula_damage_kind_effect"
        effect.display_name = "Invalid Formula Damage Kind Effect"
        effect.scope = "target"
        effect.trigger_names = PackedStringArray(["on_cast"])
        effect.duration_mode = "permanent"
        effect.payloads.clear()
        effect.payloads.append(payload)
        content_index.register_resource(effect)
    )
    if not _errors_contain(errors, "effect[test_invalid_formula_damage_kind_effect].damage invalid damage_kind for formula: none"):
        return harness.fail_result("missing formula damage_kind validation")
    return harness.pass_result()

func _test_formula_damage_kind_resolution(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var inherited_result = _run_formula_skill_inherited_kind_case(core, sample_factory)
    if inherited_result.has("error"):
        return harness.fail_result(str(inherited_result["error"]))
    if int(inherited_result["damage"]) != int(inherited_result["expected_damage"]):
        return harness.fail_result("skill-chain formula damage should inherit skill damage_kind and stat stages")
    if not is_equal_approx(float(inherited_result["type_effectiveness"]), 2.0):
        return harness.fail_result("skill-chain formula damage should keep inherited combat_type effectiveness")

    var non_skill_result = _run_non_skill_formula_damage_kind_case(core, sample_factory)
    if non_skill_result.has("error"):
        return harness.fail_result(str(non_skill_result["error"]))
    if int(non_skill_result["damage"]) != int(non_skill_result["expected_damage"]):
        return harness.fail_result("non-skill formula damage should use payload damage_kind and stat stages")
    if not is_equal_approx(float(non_skill_result["type_effectiveness"]), 1.0):
        return harness.fail_result("non-skill formula damage should stay neutral")

    return harness.pass_result()

func _test_fixed_type_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var payload = DamagePayloadScript.new()
        payload.payload_type = "damage"
        payload.amount = 10
        payload.use_formula = false
        payload.combat_type_id = "unknown_type"
        var effect = EffectDefinitionScript.new()
        effect.id = "test_fixed_type_validation_effect"
        effect.display_name = "Fixed Type Validation"
        effect.scope = "target"
        effect.trigger_names = PackedStringArray(["on_cast"])
        effect.duration_mode = "permanent"
        effect.payloads.clear()
        effect.payloads.append(payload)
        content_index.register_resource(effect)
    )
    if not _errors_contain(errors, "effect[test_fixed_type_validation_effect].damage combat_type_id missing combat type: unknown_type"):
        return harness.fail_result("missing fixed damage combat_type validation")
    return harness.pass_result()

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

func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
    var content_index = harness.build_loaded_content_index(sample_factory)
    mutate.call(content_index)
    return content_index.validate_snapshot()

func _run_formula_skill_inherited_kind_case(core, sample_factory) -> Dictionary:
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())

    var payload = DamagePayloadScript.new()
    payload.payload_type = "damage"
    payload.amount = 30
    payload.use_formula = true
    payload.damage_kind = "physical"

    var effect = EffectDefinitionScript.new()
    effect.id = "test_formula_inherit_kind_effect"
    effect.display_name = "Formula Inherit Kind Effect"
    effect.scope = "target"
    effect.trigger_names = PackedStringArray(["on_cast"])
    effect.duration_mode = "permanent"
    effect.payloads.clear()
    effect.payloads.append(payload)
    content_index.register_resource(effect)

    var skill = SkillDefinitionScript.new()
    skill.id = "test_formula_inherit_kind_skill"
    skill.display_name = "Formula Inherit Kind Skill"
    skill.damage_kind = "special"
    skill.power = 0
    skill.accuracy = 100
    skill.mp_cost = 0
    skill.priority = 0
    skill.targeting = "enemy_active_slot"
    skill.combat_type_id = "fire"
    skill.effects_on_cast_ids = PackedStringArray([effect.id])
    content_index.register_resource(skill)
    content_index.units["sample_pyron"].skill_ids[0] = skill.id

    var harmless_skill = SkillDefinitionScript.new()
    harmless_skill.id = "test_harmless_wait_inherit"
    harmless_skill.display_name = "Harmless Wait Inherit"
    harmless_skill.damage_kind = "none"
    harmless_skill.power = 0
    harmless_skill.accuracy = 100
    harmless_skill.mp_cost = 0
    harmless_skill.priority = 0
    harmless_skill.targeting = "self"
    content_index.register_resource(harmless_skill)
    content_index.units["sample_mossaur"].skill_ids[0] = harmless_skill.id

    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[1].starting_index = 2
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 571)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    _configure_special_formula_bias(actor, target)
    var expected_damage: int = min(target.current_hp, _calc_expected_formula_damage(core, battle_state, actor, target, payload.amount, "special", 2.0))

    var commands: Array = [
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
            "actor_public_id": "P2-C",
            "skill_id": harmless_skill.id,
        }),
    ]
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)
    var effect_damage_event = _find_effect_damage_event(core.battle_logger.event_log)
    if effect_damage_event == null or effect_damage_event.value_changes.is_empty():
        return {"error": "missing inherited formula damage event"}
    return {
        "damage": abs(int(effect_damage_event.value_changes[0].delta)),
        "expected_damage": expected_damage,
        "type_effectiveness": effect_damage_event.type_effectiveness,
    }

func _run_non_skill_formula_damage_kind_case(core, sample_factory) -> Dictionary:
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())

    var payload = DamagePayloadScript.new()
    payload.payload_type = "damage"
    payload.amount = 18
    payload.use_formula = true
    payload.damage_kind = "special"

    var effect = EffectDefinitionScript.new()
    effect.id = "test_turn_start_formula_damage_effect"
    effect.display_name = "Turn Start Formula Damage Effect"
    effect.scope = "self"
    effect.trigger_names = PackedStringArray(["turn_start"])
    effect.duration_mode = "permanent"
    effect.payloads.clear()
    effect.payloads.append(payload)
    content_index.register_resource(effect)

    var passive = PassiveSkillDefinitionScript.new()
    passive.id = "test_turn_start_formula_damage_passive"
    passive.display_name = "Turn Start Formula Damage Passive"
    passive.trigger_names = PackedStringArray(["turn_start"])
    passive.effect_ids = PackedStringArray([effect.id])
    content_index.register_resource(passive)
    content_index.units["sample_pyron"].passive_skill_id = passive.id

    var battle_setup = sample_factory.build_sample_setup()
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 601)
    var actor = battle_state.get_side("P1").get_active_unit()
    _configure_self_special_formula_bias(actor)
    var expected_damage: int = min(actor.current_hp, _calc_expected_formula_damage(core, battle_state, actor, actor, payload.amount, "special", 1.0))

    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    var effect_damage_event = _find_effect_damage_event(core.battle_logger.event_log)
    if effect_damage_event == null or effect_damage_event.value_changes.is_empty():
        return {"error": "missing non-skill formula damage event"}
    return {
        "damage": abs(int(effect_damage_event.value_changes[0].delta)),
        "expected_damage": expected_damage,
        "type_effectiveness": effect_damage_event.type_effectiveness,
    }

func _build_initialized_battle(core, content_index, battle_setup, seed: int):
    core.rng_service.reset(seed)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, battle_setup)
    return battle_state

func _find_effect_damage_event(event_log: Array):
    for ev in event_log:
        if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).find("dealt") == -1 and String(ev.payload_summary).find("recoil") == -1:
            return ev
    return null

func _configure_special_formula_bias(actor, target) -> void:
    actor.base_attack = 24
    actor.base_sp_attack = 120
    actor.stat_stages["attack"] = -2
    actor.stat_stages["sp_attack"] = 2
    target.base_defense = 120
    target.base_sp_defense = 24
    target.stat_stages["defense"] = 2
    target.stat_stages["sp_defense"] = -2

func _configure_self_special_formula_bias(actor) -> void:
    actor.base_attack = 18
    actor.base_sp_attack = 96
    actor.base_defense = 96
    actor.base_sp_defense = 18
    actor.stat_stages["attack"] = -2
    actor.stat_stages["sp_attack"] = 2
    actor.stat_stages["defense"] = 2
    actor.stat_stages["sp_defense"] = -2

func _calc_expected_formula_damage(core, battle_state, actor, target, amount: int, damage_kind: String, type_effectiveness: float) -> int:
    var attack_stat_name := "attack"
    var defense_stat_name := "defense"
    var attack_value: int = actor.base_attack
    var defense_value: int = target.base_defense
    if damage_kind == "special":
        attack_stat_name = "sp_attack"
        defense_stat_name = "sp_defense"
        attack_value = actor.base_sp_attack
        defense_value = target.base_sp_defense
    attack_value = core.stat_calculator.calc_effective_stat(attack_value, int(actor.stat_stages.get(attack_stat_name, 0)))
    defense_value = core.stat_calculator.calc_effective_stat(defense_value, int(target.stat_stages.get(defense_stat_name, 0)))
    return core.damage_service.apply_final_mod(
        core.damage_service.calc_base_damage(battle_state.battle_level, max(1, amount), attack_value, defense_value),
        type_effectiveness
    )

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
    for error_msg in errors:
        if String(error_msg).find(expected_fragment) != -1:
            return true
    return false
