extends RefCounted
class_name DamagePayloadContractTestHelper

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
    var content_index = harness.build_loaded_content_index(sample_factory)
    mutate.call(content_index)
    return content_index.validate_snapshot()

func run_formula_skill_inherited_kind_case(core, sample_factory) -> Dictionary:
    var content_index = BattleContentIndexScript.new()
    var snapshot_paths_result: Dictionary = sample_factory.content_snapshot_paths_result()
    if not bool(snapshot_paths_result.get("ok", false)):
        return {"error": str(snapshot_paths_result.get("error_message", "content snapshot path build failed"))}
    content_index.load_snapshot(snapshot_paths_result.get("data", PackedStringArray()))

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
    var battle_state = build_initialized_battle(core, content_index, battle_setup, 571)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    _configure_special_formula_bias(actor, target)
    var expected_damage: int = min(target.current_hp, _calc_expected_formula_damage(core, battle_state, actor, target, payload.amount, "special", 2.0))

    var commands: Array = [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-C",
            "skill_id": harmless_skill.id,
        }),
    ]
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, commands)
    var effect_damage_event = find_effect_damage_event(core.service("battle_logger").event_log)
    if effect_damage_event == null or effect_damage_event.value_changes.is_empty():
        return {"error": "missing inherited formula damage event"}
    return {
        "damage": abs(int(effect_damage_event.value_changes[0].delta)),
        "expected_damage": expected_damage,
        "type_effectiveness": effect_damage_event.type_effectiveness,
    }

func run_non_skill_formula_damage_kind_case(core, sample_factory) -> Dictionary:
    var content_index = BattleContentIndexScript.new()
    var snapshot_paths_result: Dictionary = sample_factory.content_snapshot_paths_result()
    if not bool(snapshot_paths_result.get("ok", false)):
        return {"error": str(snapshot_paths_result.get("error_message", "content snapshot path build failed"))}
    content_index.load_snapshot(snapshot_paths_result.get("data", PackedStringArray()))

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
    var battle_state = build_initialized_battle(core, content_index, battle_setup, 601)
    var actor = battle_state.get_side("P1").get_active_unit()
    _configure_self_special_formula_bias(actor)
    var expected_damage: int = min(actor.current_hp, _calc_expected_formula_damage(core, battle_state, actor, actor, payload.amount, "special", 1.0))

    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
    var effect_damage_event = find_effect_damage_event(core.service("battle_logger").event_log)
    if effect_damage_event == null or effect_damage_event.value_changes.is_empty():
        return {"error": "missing non-skill formula damage event"}
    return {
        "damage": abs(int(effect_damage_event.value_changes[0].delta)),
        "expected_damage": expected_damage,
        "type_effectiveness": effect_damage_event.type_effectiveness,
    }

func build_initialized_battle(core, content_index, battle_setup, seed: int):
    core.service("rng_service").reset(seed)
    core.service("id_factory").reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.service("id_factory").next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
    core.service("battle_initializer").initialize_battle(battle_state, content_index, battle_setup)
    return battle_state

func find_effect_damage_event(event_log: Array):
    for ev in event_log:
        if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).find("dealt") == -1 and String(ev.payload_summary).find("recoil") == -1:
            return ev
    return null

func errors_contain(errors: Array, expected_fragment: String) -> bool:
    for error_msg in errors:
        if String(error_msg).find(expected_fragment) != -1:
            return true
    return false

func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
    return validate_with_sample_mutation(harness, sample_factory, mutate)

func _run_formula_skill_inherited_kind_case(core, sample_factory) -> Dictionary:
    return run_formula_skill_inherited_kind_case(core, sample_factory)

func _run_non_skill_formula_damage_kind_case(core, sample_factory) -> Dictionary:
    return run_non_skill_formula_damage_kind_case(core, sample_factory)

func _build_initialized_battle(core, content_index, battle_setup, seed: int):
    return build_initialized_battle(core, content_index, battle_setup, seed)

func _find_effect_damage_event(event_log: Array):
    return find_effect_damage_event(event_log)

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
    return errors_contain(errors, expected_fragment)

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
    attack_value = core.service("stat_calculator").calc_effective_stat(attack_value, int(actor.stat_stages.get(attack_stat_name, 0)))
    defense_value = core.service("stat_calculator").calc_effective_stat(defense_value, int(target.stat_stages.get(defense_stat_name, 0)))
    return core.service("damage_service").apply_final_mod(
        core.service("damage_service").calc_base_damage(battle_state.battle_level, max(1, amount), attack_value, defense_value),
        type_effectiveness
    )
