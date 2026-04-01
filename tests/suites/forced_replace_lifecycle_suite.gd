extends RefCounted
class_name ForcedReplaceLifecycleSuite

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class TestReplacementSelector:
    extends "res://src/battle_core/lifecycle/replacement_selector.gd"

    var next_selection: Variant = null

    func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
        return next_selection

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("forced_replace_success_chain", failures, Callable(self, "_test_forced_replace_success_chain").bind(harness))
    runner.run_test("forced_replace_preserves_persistent_runtime_contract", failures, Callable(self, "_test_forced_replace_preserves_persistent_runtime_contract").bind(harness))
func _test_forced_replace_success_chain(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var forced_payload = ForcedReplacePayloadScript.new()
    forced_payload.payload_type = "forced_replace"
    forced_payload.scope = "target"
    forced_payload.selector_reason = "forced_replace"
    var forced_effect = EffectDefinitionScript.new()
    forced_effect.id = "test_forced_replace_effect"
    forced_effect.display_name = "Forced Replace Effect"
    forced_effect.scope = "target"
    forced_effect.trigger_names = PackedStringArray(["on_cast"])
    forced_effect.payloads.clear()
    forced_effect.payloads.append(forced_payload)
    content_index.register_resource(forced_effect)

    var forced_skill = SkillDefinitionScript.new()
    forced_skill.id = "test_forced_replace_skill"
    forced_skill.display_name = "Forced Replace Skill"
    forced_skill.damage_kind = "none"
    forced_skill.power = 0
    forced_skill.accuracy = 100
    forced_skill.mp_cost = 0
    forced_skill.priority = 0
    forced_skill.targeting = "enemy_active_slot"
    forced_skill.effects_on_cast_ids = PackedStringArray([forced_effect.id])
    content_index.register_resource(forced_skill)
    if not content_index.units["sample_pyron"].skill_ids.has(forced_skill.id):
        content_index.units["sample_pyron"].skill_ids[0] = forced_skill.id

    var switch_payload = StatModPayloadScript.new()
    switch_payload.payload_type = "stat_mod"
    switch_payload.stat_name = "attack"
    switch_payload.stage_delta = 1
    var switch_effect = EffectDefinitionScript.new()
    switch_effect.id = "test_forced_replace_on_switch_effect"
    switch_effect.display_name = "Forced Replace On Switch"
    switch_effect.scope = "self"
    switch_effect.trigger_names = PackedStringArray(["on_switch"])
    switch_effect.payloads.clear()
    switch_effect.payloads.append(switch_payload)
    var switch_passive = PassiveSkillDefinitionScript.new()
    switch_passive.id = "test_forced_replace_on_switch_passive"
    switch_passive.display_name = "Forced Replace On Switch Passive"
    switch_passive.trigger_names = PackedStringArray(["on_switch"])
    switch_passive.effect_ids = PackedStringArray([switch_effect.id])
    content_index.register_resource(switch_effect)
    content_index.register_resource(switch_passive)

    var exit_payload = StatModPayloadScript.new()
    exit_payload.payload_type = "stat_mod"
    exit_payload.stat_name = "defense"
    exit_payload.stage_delta = 1
    var exit_effect = EffectDefinitionScript.new()
    exit_effect.id = "test_forced_replace_on_exit_effect"
    exit_effect.display_name = "Forced Replace On Exit"
    exit_effect.scope = "self"
    exit_effect.trigger_names = PackedStringArray(["on_exit"])
    exit_effect.payloads.clear()
    exit_effect.payloads.append(exit_payload)
    var exit_item = PassiveItemDefinitionScript.new()
    exit_item.id = "test_forced_replace_on_exit_item"
    exit_item.display_name = "Forced Replace On Exit Item"
    exit_item.trigger_names = PackedStringArray(["on_exit"])
    exit_item.effect_ids = PackedStringArray([exit_effect.id])
    content_index.register_resource(exit_effect)
    content_index.register_resource(exit_item)

    var enter_payload = StatModPayloadScript.new()
    enter_payload.payload_type = "stat_mod"
    enter_payload.stat_name = "speed"
    enter_payload.stage_delta = 1
    var enter_effect = EffectDefinitionScript.new()
    enter_effect.id = "test_forced_replace_on_enter_effect"
    enter_effect.display_name = "Forced Replace On Enter"
    enter_effect.scope = "self"
    enter_effect.trigger_names = PackedStringArray(["on_enter"])
    enter_effect.payloads.clear()
    enter_effect.payloads.append(enter_payload)
    var enter_passive = PassiveSkillDefinitionScript.new()
    enter_passive.id = "test_forced_replace_on_enter_passive"
    enter_passive.display_name = "Forced Replace On Enter Passive"
    enter_passive.trigger_names = PackedStringArray(["on_enter"])
    enter_passive.effect_ids = PackedStringArray([enter_effect.id])
    content_index.register_resource(enter_effect)
    content_index.register_resource(enter_passive)

    content_index.units["sample_tidekit"].passive_skill_id = switch_passive.id
    content_index.units["sample_tidekit"].passive_item_id = exit_item.id
    content_index.units["sample_mossaur"].passive_skill_id = enter_passive.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 220)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    if p1_active == null or p2_active == null:
        return harness.fail_result("missing active units for forced_replace success test")
    p1_active.base_speed = 999
    var selected_unit = battle_state.get_unit_by_public_id("P2-C")
    if selected_unit == null:
        return harness.fail_result("missing selected replacement unit P2-C")

    var selector := TestReplacementSelector.new()
    selector.next_selection = selected_unit.unit_instance_id
    core.replacement_service.replacement_selector = selector

    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": forced_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ])
    if battle_state.battle_result.finished and battle_state.battle_result.reason == ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
        return harness.fail_result("forced_replace success path should not fail with invalid_replacement_selection")
    if battle_state.get_side("P2").get_active_unit().unit_instance_id != selected_unit.unit_instance_id:
        return harness.fail_result("forced_replace did not replace target with selected bench unit")

    var switch_idx := -1
    var on_switch_effect_idx := -1
    var on_exit_effect_idx := -1
    var state_exit_idx := -1
    var state_replace_idx := -1
    var state_enter_idx := -1
    var on_enter_effect_idx := -1
    for i in range(core.battle_logger.event_log.size()):
        var ev = core.battle_logger.event_log[i]
        if switch_idx == -1 and ev.event_type == EventTypesScript.STATE_SWITCH and ev.leave_reason == "forced_replace" and ev.source_instance_id == p2_active.unit_instance_id:
            switch_idx = i
            continue
        if switch_idx == -1:
            continue
        if on_switch_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.trigger_name == "on_switch" and ev.target_instance_id == p2_active.unit_instance_id:
            on_switch_effect_idx = i
        if on_exit_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.trigger_name == "on_exit" and ev.target_instance_id == p2_active.unit_instance_id:
            on_exit_effect_idx = i
        if state_exit_idx == -1 and ev.event_type == EventTypesScript.STATE_EXIT and ev.leave_reason == "forced_replace" and ev.target_instance_id == p2_active.unit_instance_id:
            state_exit_idx = i
        if state_replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE and ev.target_instance_id == selected_unit.unit_instance_id:
            state_replace_idx = i
        if state_enter_idx == -1 and ev.event_type == EventTypesScript.STATE_ENTER and ev.target_instance_id == selected_unit.unit_instance_id and state_replace_idx != -1 and i > state_replace_idx:
            state_enter_idx = i
        if on_enter_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.trigger_name == "on_enter" and ev.target_instance_id == selected_unit.unit_instance_id and state_enter_idx != -1 and i > state_enter_idx:
            on_enter_effect_idx = i
    if switch_idx == -1 or on_switch_effect_idx == -1 or on_exit_effect_idx == -1 or state_exit_idx == -1 or state_replace_idx == -1 or state_enter_idx == -1 or on_enter_effect_idx == -1:
        return harness.fail_result("missing forced_replace lifecycle events")
    if not (switch_idx < on_switch_effect_idx and on_switch_effect_idx < on_exit_effect_idx and on_exit_effect_idx < state_exit_idx and state_exit_idx < state_replace_idx and state_replace_idx < state_enter_idx and state_enter_idx < on_enter_effect_idx):
        return harness.fail_result("forced_replace lifecycle ordering mismatch")
    return harness.pass_result()

func _test_forced_replace_preserves_persistent_runtime_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var forced_payload = ForcedReplacePayloadScript.new()
    forced_payload.payload_type = "forced_replace"
    forced_payload.scope = "target"
    forced_payload.selector_reason = "forced_replace"
    var forced_effect = EffectDefinitionScript.new()
    forced_effect.id = "test_forced_replace_persistent_effect"
    forced_effect.display_name = "Forced Replace Persistent Effect"
    forced_effect.scope = "target"
    forced_effect.trigger_names = PackedStringArray(["on_cast"])
    forced_effect.payloads.append(forced_payload)
    content_index.register_resource(forced_effect)

    var forced_skill = SkillDefinitionScript.new()
    forced_skill.id = "test_forced_replace_persistent_skill"
    forced_skill.display_name = "Forced Replace Persistent Skill"
    forced_skill.damage_kind = "none"
    forced_skill.power = 0
    forced_skill.accuracy = 100
    forced_skill.mp_cost = 0
    forced_skill.priority = 0
    forced_skill.targeting = "enemy_active_slot"
    forced_skill.effects_on_cast_ids = PackedStringArray([forced_effect.id])
    content_index.register_resource(forced_skill)
    content_index.units["sample_pyron"].skill_ids[0] = forced_skill.id

    var bench_stat_payload = StatModPayloadScript.new()
    bench_stat_payload.payload_type = "stat_mod"
    bench_stat_payload.stat_name = "speed"
    bench_stat_payload.stage_delta = 1
    var bench_effect = EffectDefinitionScript.new()
    bench_effect.id = "test_forced_replace_persistent_bench_effect"
    bench_effect.display_name = "Forced Replace Persistent Bench Effect"
    bench_effect.scope = "self"
    bench_effect.duration_mode = "turns"
    bench_effect.duration = 2
    bench_effect.decrement_on = "turn_end"
    bench_effect.stacking = "replace"
    bench_effect.trigger_names = PackedStringArray(["turn_end"])
    bench_effect.payloads.append(bench_stat_payload)
    bench_effect.persists_on_switch = true
    content_index.register_resource(bench_effect)

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 221)
    var actor = battle_state.get_side("P1").get_active_unit()
    var target = battle_state.get_side("P2").get_active_unit()
    if actor == null or target == null:
        return harness.fail_result("missing active units for forced_replace persistent contract")
    if core.effect_instance_service.create_instance(
        bench_effect,
        target.unit_instance_id,
        battle_state,
        "test_forced_replace_persistent_source",
        0,
        target.base_speed
    ) == null:
        return harness.fail_result("failed to create forced_replace persistent effect instance")
    var persistent_rule_mod = RuleModPayloadScript.new()
    persistent_rule_mod.payload_type = "rule_mod"
    persistent_rule_mod.mod_kind = "mp_regen"
    persistent_rule_mod.mod_op = "add"
    persistent_rule_mod.value = 3
    persistent_rule_mod.scope = "self"
    persistent_rule_mod.duration_mode = "turns"
    persistent_rule_mod.duration = 2
    persistent_rule_mod.decrement_on = "turn_end"
    persistent_rule_mod.stacking = "replace"
    persistent_rule_mod.persists_on_switch = true
    persistent_rule_mod.stacking_source_key = "forced_replace_persistent_group"
    if core.rule_mod_service.create_instance(
        persistent_rule_mod,
        {"scope": "unit", "id": target.unit_instance_id},
        battle_state,
        "test_forced_replace_persistent_rule_mod",
        0,
        target.base_speed
    ) == null:
        return harness.fail_result("failed to create forced_replace persistent rule_mod")
    var selected_unit = battle_state.get_unit_by_public_id("P2-C")
    if selected_unit == null:
        return harness.fail_result("missing selected replacement unit P2-C")
    var selector := TestReplacementSelector.new()
    selector.next_selection = selected_unit.unit_instance_id
    core.replacement_service.replacement_selector = selector
    actor.base_speed = 999
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": forced_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    var replaced_unit = battle_state.get_unit_by_public_id("P2-A")
    if replaced_unit == null:
        return harness.fail_result("missing forced-replaced unit P2-A")
    var bench_effect_instance = null
    var bench_rule_mod = null
    for effect_instance in replaced_unit.effect_instances:
        if String(effect_instance.def_id) == bench_effect.id:
            bench_effect_instance = effect_instance
            break
    for rule_mod_instance in replaced_unit.rule_mod_instances:
        if String(rule_mod_instance.mod_kind) == "mp_regen":
            bench_rule_mod = rule_mod_instance
            break
    if bench_effect_instance == null or int(bench_effect_instance.remaining) != 1:
        return harness.fail_result("forced_replace should keep persistent effect on replaced unit and decrement it on bench")
    if bench_rule_mod == null or int(bench_rule_mod.remaining) != 1:
        return harness.fail_result("forced_replace should keep persistent rule_mod on replaced unit and decrement it on bench")
    if int(replaced_unit.stat_stages.get("speed", 0)) != 0:
        return harness.fail_result("replaced bench unit should not trigger normal turn_end payloads while off-field")
    return harness.pass_result()
