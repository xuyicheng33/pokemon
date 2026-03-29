extends RefCounted
class_name LifecycleReplacementFlowSuite

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class TestReplacementSelector:
    extends "res://src/battle_core/lifecycle/replacement_selector.gd"

    var next_selection: Variant = null

    func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
        return next_selection

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("lifecycle_faint_replace_chain", failures, Callable(self, "_test_lifecycle_faint_replace_chain").bind(harness))
    runner.run_test("manual_switch_lifecycle_chain", failures, Callable(self, "_test_manual_switch_lifecycle_chain").bind(harness))
    runner.run_test("replacement_selector_paths", failures, Callable(self, "_test_replacement_selector_paths").bind(harness))
func _test_lifecycle_faint_replace_chain(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var kill_payload = StatModPayloadScript.new()
    kill_payload.payload_type = "stat_mod"
    kill_payload.stat_name = "attack"
    kill_payload.stage_delta = 1
    var kill_effect = EffectDefinitionScript.new()
    kill_effect.id = "test_on_kill_buff_effect"
    kill_effect.display_name = "On Kill Buff"
    kill_effect.scope = "self"
    kill_effect.trigger_names = PackedStringArray(["on_kill"])
    kill_effect.payloads.clear()
    kill_effect.payloads.append(kill_payload)
    var kill_passive = PassiveSkillDefinitionScript.new()
    kill_passive.id = "test_on_kill_passive"
    kill_passive.display_name = "On Kill Passive"
    kill_passive.trigger_names = PackedStringArray(["on_kill"])
    kill_passive.effect_ids = PackedStringArray([kill_effect.id])
    content_index.register_resource(kill_effect)
    content_index.register_resource(kill_passive)
    content_index.units["sample_pyron"].passive_skill_id = kill_passive.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 103)
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p2_active.current_hp = 1
    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)

    var faint_idx := -1
    var kill_effect_idx := -1
    var exit_idx := -1
    var replace_idx := -1
    var enter_idx := -1
    for i in range(core.battle_logger.event_log.size()):
        var ev = core.battle_logger.event_log[i]
        if faint_idx == -1 and ev.event_type == EventTypesScript.STATE_FAINT:
            faint_idx = i
        if kill_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
            kill_effect_idx = i
        if exit_idx == -1 and ev.event_type == EventTypesScript.STATE_EXIT:
            exit_idx = i
        if replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE:
            replace_idx = i
        if ev.event_type == EventTypesScript.STATE_ENTER and i > replace_idx and replace_idx != -1:
            enter_idx = i
            break
    if faint_idx == -1 or exit_idx == -1 or replace_idx == -1 or enter_idx == -1:
        return harness.fail_result("missing lifecycle events in faint window")
    if kill_effect_idx == -1:
        return harness.fail_result("on_kill trigger effect missing")
    if not (faint_idx < kill_effect_idx and kill_effect_idx < exit_idx and exit_idx < replace_idx and replace_idx < enter_idx):
        return harness.fail_result("faint lifecycle ordering mismatch")
    return harness.pass_result()

func _test_manual_switch_lifecycle_chain(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var switch_payload = StatModPayloadScript.new()
    switch_payload.payload_type = "stat_mod"
    switch_payload.stat_name = "attack"
    switch_payload.stage_delta = 1
    var switch_effect = EffectDefinitionScript.new()
    switch_effect.id = "test_manual_switch_on_switch_effect"
    switch_effect.display_name = "Manual Switch On Switch"
    switch_effect.scope = "self"
    switch_effect.trigger_names = PackedStringArray(["on_switch"])
    switch_effect.payloads.clear()
    switch_effect.payloads.append(switch_payload)
    var switch_passive = PassiveSkillDefinitionScript.new()
    switch_passive.id = "test_manual_switch_on_switch_passive"
    switch_passive.display_name = "Manual Switch On Switch Passive"
    switch_passive.trigger_names = PackedStringArray(["on_switch"])
    switch_passive.effect_ids = PackedStringArray([switch_effect.id])
    content_index.register_resource(switch_effect)
    content_index.register_resource(switch_passive)

    var exit_payload = StatModPayloadScript.new()
    exit_payload.payload_type = "stat_mod"
    exit_payload.stat_name = "defense"
    exit_payload.stage_delta = 1
    var exit_effect = EffectDefinitionScript.new()
    exit_effect.id = "test_manual_switch_on_exit_effect"
    exit_effect.display_name = "Manual Switch On Exit"
    exit_effect.scope = "self"
    exit_effect.trigger_names = PackedStringArray(["on_exit"])
    exit_effect.payloads.clear()
    exit_effect.payloads.append(exit_payload)
    var exit_item = PassiveItemDefinitionScript.new()
    exit_item.id = "test_manual_switch_on_exit_item"
    exit_item.display_name = "Manual Switch On Exit Item"
    exit_item.trigger_names = PackedStringArray(["on_exit"])
    exit_item.effect_ids = PackedStringArray([exit_effect.id])
    content_index.register_resource(exit_effect)
    content_index.register_resource(exit_item)

    var enter_payload = StatModPayloadScript.new()
    enter_payload.payload_type = "stat_mod"
    enter_payload.stat_name = "speed"
    enter_payload.stage_delta = 1
    var enter_effect = EffectDefinitionScript.new()
    enter_effect.id = "test_manual_switch_on_enter_effect"
    enter_effect.display_name = "Manual Switch On Enter"
    enter_effect.scope = "self"
    enter_effect.trigger_names = PackedStringArray(["on_enter"])
    enter_effect.payloads.clear()
    enter_effect.payloads.append(enter_payload)
    var enter_passive = PassiveSkillDefinitionScript.new()
    enter_passive.id = "test_manual_switch_on_enter_passive"
    enter_passive.display_name = "Manual Switch On Enter Passive"
    enter_passive.trigger_names = PackedStringArray(["on_enter"])
    enter_passive.effect_ids = PackedStringArray([enter_effect.id])
    content_index.register_resource(enter_effect)
    content_index.register_resource(enter_passive)

    content_index.units["sample_pyron"].passive_skill_id = switch_passive.id
    content_index.units["sample_pyron"].passive_item_id = exit_item.id
    content_index.units["sample_mossaur"].passive_skill_id = enter_passive.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 108)
    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "target_public_id": "P1-B",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)

    var switch_idx := -1
    var on_switch_effect_idx := -1
    var on_exit_effect_idx := -1
    var state_exit_idx := -1
    var state_enter_idx := -1
    var on_enter_effect_idx := -1
    for i in range(core.battle_logger.event_log.size()):
        var ev = core.battle_logger.event_log[i]
        if switch_idx == -1 and ev.event_type == EventTypesScript.STATE_SWITCH:
            switch_idx = i
        if on_switch_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
            on_switch_effect_idx = i
        if on_exit_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_item:"):
            on_exit_effect_idx = i
        if state_exit_idx == -1 and ev.event_type == EventTypesScript.STATE_EXIT:
            state_exit_idx = i
        if state_enter_idx == -1 and ev.event_type == EventTypesScript.STATE_ENTER and ev.target_instance_id == battle_state.get_unit_by_public_id("P1-B").unit_instance_id:
            state_enter_idx = i
        if on_enter_effect_idx == -1 and state_enter_idx != -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:") and i > state_enter_idx:
            on_enter_effect_idx = i
    if switch_idx == -1 or on_switch_effect_idx == -1 or on_exit_effect_idx == -1 or state_exit_idx == -1 or state_enter_idx == -1 or on_enter_effect_idx == -1:
        return harness.fail_result("missing manual switch lifecycle events")
    if not (switch_idx < on_switch_effect_idx and on_switch_effect_idx < on_exit_effect_idx and on_exit_effect_idx < state_exit_idx and state_exit_idx < state_enter_idx and state_enter_idx < on_enter_effect_idx):
        return harness.fail_result("manual switch lifecycle ordering mismatch (%d,%d,%d,%d,%d,%d)" % [switch_idx, on_switch_effect_idx, on_exit_effect_idx, state_exit_idx, state_enter_idx, on_enter_effect_idx])
    return harness.pass_result()

func _test_replacement_selector_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var legal_state = harness.build_initialized_battle(core, content_index, sample_factory, 215)
    var legal_side = legal_state.get_side("P1")
    if legal_side == null or legal_side.bench_order.size() < 2:
        return harness.fail_result("expected at least 2 legal bench candidates for replacement selector test")
    var legal_selector := TestReplacementSelector.new()
    var chosen_unit_id: String = legal_side.bench_order[1]
    legal_selector.next_selection = chosen_unit_id
    core.replacement_service.replacement_selector = legal_selector
    var legal_result: Dictionary = core.replacement_service.resolve_replacement(legal_state, legal_side, "forced_replace")
    if legal_result.get("invalid_code", null) != null:
        return harness.fail_result("legal replacement selection should pass")
    var entered_unit = legal_result.get("entered_unit", null)
    if entered_unit == null or entered_unit.unit_instance_id != chosen_unit_id:
        return harness.fail_result("replacement selector did not pick requested legal target")

    var invalid_state = harness.build_initialized_battle(core, content_index, sample_factory, 216)
    var invalid_side = invalid_state.get_side("P1")
    var invalid_selector := TestReplacementSelector.new()
    invalid_selector.next_selection = "unit_not_in_bench"
    core.replacement_service.replacement_selector = invalid_selector
    var invalid_result: Dictionary = core.replacement_service.resolve_replacement(invalid_state, invalid_side, "forced_replace")
    if invalid_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
        return harness.fail_result("invalid replacement target should fail-fast with invalid_replacement_selection")

    var empty_state = harness.build_initialized_battle(core, content_index, sample_factory, 217)
    var empty_side = empty_state.get_side("P1")
    var empty_selector := TestReplacementSelector.new()
    empty_selector.next_selection = null
    core.replacement_service.replacement_selector = empty_selector
    var empty_result: Dictionary = core.replacement_service.resolve_replacement(empty_state, empty_side, "faint")
    if empty_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
        return harness.fail_result("empty replacement selection should fail-fast with invalid_replacement_selection")

    return harness.pass_result()
