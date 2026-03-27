extends RefCounted
class_name CombatTypeSuite

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const BattleSetupScript := preload("res://src/battle_core/contracts/battle_setup.gd")
const SideSetupScript := preload("res://src/battle_core/contracts/side_setup.gd")
const CombatTypeChartEntryScript := preload("res://src/battle_core/content/combat_type_chart_entry.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CombatTypeServiceScript := preload("res://src/battle_core/math/combat_type_service.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("combat_type_content_validation", failures, Callable(self, "_test_combat_type_content_validation").bind(harness))
    runner.run_test("combat_type_chart_math", failures, Callable(self, "_test_combat_type_chart_math").bind(harness))
    runner.run_test("combat_type_direct_damage_and_logs", failures, Callable(self, "_test_combat_type_direct_damage_and_logs").bind(harness))
    runner.run_test("combat_type_formula_damage_paths", failures, Callable(self, "_test_combat_type_formula_damage_paths").bind(harness))
    runner.run_test("combat_type_default_and_recoil_paths", failures, Callable(self, "_test_combat_type_default_and_recoil_paths").bind(harness))

func _test_combat_type_content_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var unknown_skill_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.skills["sample_strike"].combat_type_id = "unknown_type"
    )
    if not _errors_contain(unknown_skill_errors, "skill[sample_strike].combat_type_id missing combat type: unknown_type"):
        return harness.fail_result("missing unknown skill combat_type validation")

    var too_many_unit_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", "water", "wood"])
    )
    if not _errors_contain(too_many_unit_errors, "unit[sample_pyron].combat_type_ids must contain at most 2 entries"):
        return harness.fail_result("missing unit max 2 combat types validation")

    var duplicate_unit_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", "fire"])
    )
    if not _errors_contain(duplicate_unit_errors, "unit[sample_pyron].combat_type_ids duplicated type: fire"):
        return harness.fail_result("missing duplicated unit combat type validation")

    var empty_unit_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        content_index.units["sample_pyron"].combat_type_ids = PackedStringArray(["fire", ""])
    )
    if not _errors_contain(empty_unit_errors, "unit[sample_pyron].combat_type_ids must not contain empty entry"):
        return harness.fail_result("missing empty unit combat type validation")

    var unknown_chart_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "unknown_type"
        entry.mul = 2.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(unknown_chart_errors, "battle_format[prototype_full_open].combat_type_chart unknown def: unknown_type"):
        return harness.fail_result("missing chart unknown type validation")

    var missing_chart_field_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.mul = 2.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(missing_chart_field_errors, "battle_format[prototype_full_open].combat_type_chart missing atk") \
    or not _errors_contain(missing_chart_field_errors, "battle_format[prototype_full_open].combat_type_chart missing def"):
        return harness.fail_result("missing chart required field validation")

    var duplicate_pair_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "wood"
        entry.mul = 2.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(duplicate_pair_errors, "battle_format[prototype_full_open].combat_type_chart duplicated pair: fire|wood"):
        return harness.fail_result("missing chart duplicated pair validation")

    var invalid_mul_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "wood"
        entry.mul = 1.5
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(invalid_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 1.5"):
        return harness.fail_result("missing chart multiplier validation")

    var zero_mul_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "fire"
        entry.def = "water"
        entry.mul = 0.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(zero_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 0"):
        return harness.fail_result("missing zero multiplier validation")

    var oversized_mul_errors = _validate_with_sample_mutation(harness, sample_factory, func(content_index):
        var entry = CombatTypeChartEntryScript.new()
        entry.atk = "water"
        entry.def = "fire"
        entry.mul = 3.0
        content_index.battle_formats["prototype_full_open"].combat_type_chart.append(entry)
    )
    if not _errors_contain(oversized_mul_errors, "battle_format[prototype_full_open].combat_type_chart invalid mul: 3"):
        return harness.fail_result("missing oversized multiplier validation")

    return harness.pass_result()

func _test_combat_type_chart_math(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var format_config = content_index.battle_formats.get("prototype_full_open", null)
    if format_config == null:
        return harness.fail_result("missing sample battle format")

    var service = CombatTypeServiceScript.new()
    service.build_chart(format_config.combat_type_chart)

    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood"])), 2.0):
        return harness.fail_result("fire -> wood should be 2.0")
    if not is_equal_approx(service.calc_effectiveness("wood", PackedStringArray(["fire"])), 0.5):
        return harness.fail_result("wood -> fire should be 0.5")
    if not is_equal_approx(service.calc_effectiveness("light", PackedStringArray(["water"])), 1.0):
        return harness.fail_result("unconfigured pair should default to 1.0")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood", "ice"])), 4.0):
        return harness.fail_result("fire -> wood+ice should multiply to 4.0")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["wood", "water"])), 1.0):
        return harness.fail_result("fire -> wood+water should multiply to 1.0")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray(["water", "dragon"])), 0.25):
        return harness.fail_result("fire -> water+dragon should multiply to 0.25")
    if not is_equal_approx(service.calc_effectiveness("", PackedStringArray(["wood"])), 1.0):
        return harness.fail_result("empty skill type should be neutral")
    if not is_equal_approx(service.calc_effectiveness("fire", PackedStringArray()), 1.0):
        return harness.fail_result("empty defender type should be neutral")
    return harness.pass_result()

func _test_combat_type_direct_damage_and_logs(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var neutral_result = _run_direct_damage_case(harness, core, sample_factory, "", null)
    if neutral_result.has("error"):
        return harness.fail_result(str(neutral_result["error"]))
    if not is_equal_approx(float(neutral_result["type_effectiveness"]), 1.0):
        return harness.fail_result("neutral direct damage should log type_effectiveness = 1.0")

    var typed_result = _run_direct_damage_case(harness, core, sample_factory, "fire", null)
    if typed_result.has("error"):
        return harness.fail_result(str(typed_result["error"]))
    if not is_equal_approx(float(typed_result["type_effectiveness"]), 2.0):
        return harness.fail_result("typed direct damage should log type_effectiveness = 2.0")
    if int(typed_result["damage"]) <= int(neutral_result["damage"]):
        return harness.fail_result("typed direct damage should exceed neutral baseline")

    var modded_result = _run_direct_damage_case(harness, core, sample_factory, "fire", 1.5)
    if modded_result.has("error"):
        return harness.fail_result(str(modded_result["error"]))
    if not is_equal_approx(float(modded_result["type_effectiveness"]), 2.0):
        return harness.fail_result("rule_mod case should still log raw type_effectiveness = 2.0")
    if int(modded_result["damage"]) <= int(typed_result["damage"]):
        return harness.fail_result("rule_mod should stack on top of type effectiveness")

    return harness.pass_result()

func _test_combat_type_formula_damage_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var inheritance_result = _run_formula_skill_case(harness, core, sample_factory)
    if inheritance_result.has("error"):
        return harness.fail_result(str(inheritance_result["error"]))
    if not is_equal_approx(float(inheritance_result["type_effectiveness"]), 2.0):
        return harness.fail_result("formula damage in skill chain should inherit skill combat_type")

    var passive_result = _run_non_skill_formula_case(harness, core, sample_factory)
    if passive_result.has("error"):
        return harness.fail_result(str(passive_result["error"]))
    if not is_equal_approx(float(passive_result["type_effectiveness"]), 1.0):
        return harness.fail_result("non-skill formula damage should stay neutral")

    return harness.pass_result()

func _test_combat_type_default_and_recoil_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = sample_factory.build_sample_setup()
    core.rng_service.reset(641)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = 641
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, battle_setup)

    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p1_active.current_mp = 0
    p1_active.regen_per_turn = 0
    p2_active.current_mp = 0
    p2_active.regen_per_turn = 0
    for bench_unit_id in battle_state.get_side("P1").bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    for bench_unit_id in battle_state.get_side("P2").bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0

    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [])

    var default_damage_found: bool = false
    var recoil_damage_found: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if String(ev.payload_summary).find("dealt") != -1:
            if not is_equal_approx(float(ev.type_effectiveness), 1.0):
                return harness.fail_result("default action damage should log neutral type_effectiveness")
            default_damage_found = true
        if String(ev.payload_summary).find("recoil") != -1:
            if not is_equal_approx(float(ev.type_effectiveness), 1.0):
                return harness.fail_result("recoil damage should log neutral type_effectiveness")
            recoil_damage_found = true
    if not default_damage_found:
        return harness.fail_result("missing default action damage log")
    if not recoil_damage_found:
        return harness.fail_result("missing recoil damage log")
    return harness.pass_result()

func _validate_with_sample_mutation(harness, sample_factory, mutate: Callable) -> Array:
    var content_index = harness.build_loaded_content_index(sample_factory)
    mutate.call(content_index)
    return content_index.validate_snapshot()

func _run_direct_damage_case(harness, core, sample_factory, skill_type_id: String, final_mod: Variant) -> Dictionary:
    var content_index = harness.build_loaded_content_index(sample_factory)
    var skill_id = "test_fire_direct_skill" if skill_type_id == "fire" else "test_neutral_direct_skill"
    var direct_skill = SkillDefinitionScript.new()
    direct_skill.id = skill_id
    direct_skill.display_name = skill_id
    direct_skill.damage_kind = "special"
    direct_skill.power = 50
    direct_skill.accuracy = 100
    direct_skill.mp_cost = 0
    direct_skill.priority = 0
    direct_skill.targeting = "enemy_active_slot"
    direct_skill.combat_type_id = skill_type_id
    content_index.register_resource(direct_skill)
    content_index.units["sample_pyron"].skill_ids[0] = direct_skill.id

    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[1].starting_index = 2
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 501)

    if final_mod != null:
        var final_mod_payload = RuleModPayloadScript.new()
        final_mod_payload.payload_type = "rule_mod"
        final_mod_payload.mod_kind = "final_mod"
        final_mod_payload.mod_op = "mul"
        final_mod_payload.value = final_mod
        final_mod_payload.scope = "self"
        final_mod_payload.duration_mode = "turns"
        final_mod_payload.duration = 1
        final_mod_payload.decrement_on = "turn_end"
        final_mod_payload.stacking = "replace"
        final_mod_payload.priority = 10
        var p1_active = battle_state.get_side("P1").get_active_unit()
        if core.rule_mod_service.create_instance(final_mod_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_direct_damage_mod", 0, p1_active.base_speed) == null:
            return {"error": "failed to create direct damage rule_mod"}

    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": direct_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-C",
            "skill_id": "sample_strike",
        }),
    ]

    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)
    var damage_event = _find_actor_damage_event(core.battle_logger.event_log, "P1-A")
    if damage_event == null or damage_event.value_changes.is_empty():
        return {"error": "missing direct damage event"}
    return {
        "damage": abs(int(damage_event.value_changes[0].delta)),
        "type_effectiveness": damage_event.type_effectiveness,
    }

func _run_formula_skill_case(harness, core, sample_factory) -> Dictionary:
    var content_index = harness.build_loaded_content_index(sample_factory)

    var payload = DamagePayloadScript.new()
    payload.payload_type = "damage"
    payload.amount = 30
    payload.use_formula = true
    payload.damage_kind = "special"

    var effect = EffectDefinitionScript.new()
    effect.id = "test_formula_fire_effect"
    effect.display_name = "Formula Fire Effect"
    effect.scope = "target"
    effect.trigger_names = PackedStringArray(["on_cast"])
    effect.duration_mode = "permanent"
    effect.payloads.clear()
    effect.payloads.append(payload)
    content_index.register_resource(effect)

    var skill = SkillDefinitionScript.new()
    skill.id = "test_formula_fire_skill"
    skill.display_name = "Formula Fire Skill"
    skill.damage_kind = "none"
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
    harmless_skill.id = "test_harmless_wait"
    harmless_skill.display_name = "Harmless Wait"
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
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 551)
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
    if effect_damage_event == null:
        return {"error": "missing formula damage event"}
    return {"type_effectiveness": effect_damage_event.type_effectiveness}

func _run_non_skill_formula_case(harness, core, sample_factory) -> Dictionary:
    var content_index = harness.build_loaded_content_index(sample_factory)

    var payload = DamagePayloadScript.new()
    payload.payload_type = "damage"
    payload.amount = 20
    payload.use_formula = true
    payload.damage_kind = "special"

    var effect = EffectDefinitionScript.new()
    effect.id = "test_enter_formula_damage_effect"
    effect.display_name = "Enter Formula Damage Effect"
    effect.scope = "self"
    effect.trigger_names = PackedStringArray(["on_enter"])
    effect.duration_mode = "permanent"
    effect.payloads.clear()
    effect.payloads.append(payload)
    content_index.register_resource(effect)

    var passive = PassiveSkillDefinitionScript.new()
    passive.id = "test_enter_formula_damage_passive"
    passive.display_name = "Enter Formula Damage Passive"
    passive.trigger_names = PackedStringArray(["on_enter"])
    passive.effect_ids = PackedStringArray([effect.id])
    content_index.register_resource(passive)
    content_index.units["sample_pyron"].passive_skill_id = passive.id

    var battle_setup = sample_factory.build_sample_setup()
    var battle_state = _build_initialized_battle(core, content_index, battle_setup, 601)
    var effect_damage_event = _find_effect_damage_event(core.battle_logger.event_log)
    if effect_damage_event == null:
        return {"error": "missing non-skill formula damage event"}
    if battle_state.battle_result != null and battle_state.battle_result.finished:
        return {"error": "non-skill formula damage should not invalidate initialization"}
    return {"type_effectiveness": effect_damage_event.type_effectiveness}

func _build_initialized_battle(core, content_index, battle_setup, seed: int):
    core.rng_service.reset(seed)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, battle_setup)
    return battle_state

func _find_actor_damage_event(event_log: Array, actor_public_id: String):
    for ev in event_log:
        if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).begins_with("%s dealt " % actor_public_id):
            return ev
    return null

func _find_effect_damage_event(event_log: Array):
    for ev in event_log:
        if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).find("dealt") == -1 and String(ev.payload_summary).find("recoil") == -1:
            return ev
    return null

func _errors_contain(errors: Array, expected_fragment: String) -> bool:
    for error_msg in errors:
        if String(error_msg).find(expected_fragment) != -1:
            return true
    return false
