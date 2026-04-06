extends RefCounted
class_name LogCauseSemanticsSuite

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const LogCauseTestHelperScript := preload("res://tests/support/log_cause_test_helper.gd")

var _helper = LogCauseTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("log_contract_semantics", failures, Callable(self, "_test_log_contract_semantics").bind(harness))
    runner.run_test("apply_effect_lifecycle_chain", failures, Callable(self, "_test_apply_effect_lifecycle_chain").bind(harness))
    runner.run_test("apply_effect_none_repeat_skips_log", failures, Callable(self, "_test_apply_effect_none_repeat_skips_log").bind(harness))
    runner.run_test("rule_mod_none_repeat_skips_log", failures, Callable(self, "_test_rule_mod_none_repeat_skips_log").bind(harness))
func _test_log_contract_semantics(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var replay_output = core.service("replay_runner").run_replay(harness.build_demo_replay_input(sample_factory, core.service("command_builder")))
    if replay_output == null:
        return harness.fail_result("replay output is null")

    var system_turn_start_event = null
    var action_cast_event = null
    var effect_damage_event = null
    for ev in replay_output.event_log:
        if system_turn_start_event == null and ev.event_type == EventTypesScript.SYSTEM_TURN_START:
            system_turn_start_event = ev
        if action_cast_event == null and ev.event_type == EventTypesScript.ACTION_CAST and ev.command_source == "manual":
            action_cast_event = ev
        if effect_damage_event == null and ev.event_type == EventTypesScript.EFFECT_DAMAGE:
            effect_damage_event = ev
    if system_turn_start_event == null or action_cast_event == null:
        return harness.fail_result("missing system/action events for log contract checks")
    if effect_damage_event == null:
        return harness.fail_result("missing effect event for log contract checks")
    if system_turn_start_event.log_schema_version != 3 or action_cast_event.log_schema_version != 3:
        return harness.fail_result("log_schema_version should be 3 for all events")
    if system_turn_start_event.chain_origin != "turn_start":
        return harness.fail_result("system event chain_origin mismatch")
    if action_cast_event.chain_origin != "action":
        return harness.fail_result("action event chain_origin mismatch")
    if system_turn_start_event.action_id != null or system_turn_start_event.action_queue_index != null or system_turn_start_event.actor_id != null:
        return harness.fail_result("system event action fields must be null")
    if system_turn_start_event.command_type != EventTypesScript.SYSTEM_TURN_START or system_turn_start_event.command_source != "system":
        return harness.fail_result("system event command fields mismatch")
    if system_turn_start_event.select_timeout != null:
        return harness.fail_result("system event select_timeout must be null")
    if action_cast_event.action_id == null or action_cast_event.actor_id == null:
        return harness.fail_result("action event should inherit root action fields")
    if action_cast_event.command_source != "manual":
        return harness.fail_result("action event command_source should be manual")
    if action_cast_event.select_timeout != false:
        return harness.fail_result("manual action chain select_timeout should be false")
    if effect_damage_event.trigger_name == null or effect_damage_event.cause_event_id == null:
        return harness.fail_result("effect event should include trigger_name and cause_event_id")
    var source_action_hit_event = _find_event(replay_output.event_log, func(ev): return ev.event_type == EventTypesScript.ACTION_HIT and ev.source_instance_id == effect_damage_event.source_instance_id)
    if source_action_hit_event == null:
        return harness.fail_result("direct damage should retain its action:hit source event")
    if effect_damage_event.cause_event_id != _event_id(source_action_hit_event):
        return harness.fail_result("direct damage cause_event_id should point to the real action:hit event")
    if effect_damage_event.cause_event_id == _event_id(effect_damage_event):
        return harness.fail_result("effect event cause_event_id must not point to itself")
    return harness.pass_result()

func _test_apply_effect_lifecycle_chain(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var dot_payload = DamagePayloadScript.new()
    dot_payload.payload_type = "dot"
    dot_payload.amount = 5
    dot_payload.use_formula = false
    var dot_effect = EffectDefinitionScript.new()
    dot_effect.id = "test_dot_tick"
    dot_effect.display_name = "Dot Tick"
    dot_effect.scope = "self"
    dot_effect.duration_mode = "turns"
    dot_effect.duration = 1
    dot_effect.decrement_on = "turn_end"
    dot_effect.stacking = "replace"
    dot_effect.priority = 0
    dot_effect.trigger_names = PackedStringArray(["turn_end"])
    dot_effect.payloads.clear()
    dot_effect.payloads.append(dot_payload)
    content_index.register_resource(dot_effect)

    var apply_payload = ApplyEffectPayloadScript.new()
    apply_payload.payload_type = "apply_effect"
    apply_payload.effect_definition_id = dot_effect.id
    var apply_effect = EffectDefinitionScript.new()
    apply_effect.id = "test_apply_dot"
    apply_effect.display_name = "Apply Dot"
    apply_effect.scope = "target"
    apply_effect.duration_mode = "permanent"
    apply_effect.trigger_names = PackedStringArray(["on_cast"])
    apply_effect.payloads.clear()
    apply_effect.payloads.append(apply_payload)
    content_index.register_resource(apply_effect)

    var dot_skill = SkillDefinitionScript.new()
    dot_skill.id = "test_dot_skill"
    dot_skill.display_name = "Dot Skill"
    dot_skill.damage_kind = "none"
    dot_skill.power = 0
    dot_skill.accuracy = 100
    dot_skill.mp_cost = 0
    dot_skill.priority = 0
    dot_skill.targeting = "enemy_active_slot"
    dot_skill.effects_on_cast_ids = PackedStringArray([apply_effect.id])
    content_index.register_resource(dot_skill)
    if not content_index.units["sample_pyron"].skill_ids.has(dot_skill.id):
        content_index.units["sample_pyron"].skill_ids[0] = dot_skill.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 211)
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p2_active.current_hp = min(p2_active.max_hp, max(20, p2_active.current_hp))
    var commands: Array = [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": dot_skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    core.service("turn_loop_controller").run_turn(battle_state, content_index, commands)

    var turn_end_event = _find_event(core.service("battle_logger").event_log, func(ev): return ev.event_type == EventTypesScript.SYSTEM_TURN_END)
    var apply_event = null
    var tick_event = null
    var remove_event = null
    for ev in core.service("battle_logger").event_log:
        if apply_event == null and ev.event_type == EventTypesScript.EFFECT_APPLY_EFFECT and String(ev.payload_summary).find(dot_effect.id) != -1:
            apply_event = ev
        if tick_event == null and ev.event_type == EventTypesScript.EFFECT_DAMAGE and ev.trigger_name == "turn_end" and String(ev.payload_summary).find("dot") != -1:
            tick_event = ev
        if remove_event == null and ev.event_type == EventTypesScript.EFFECT_REMOVE_EFFECT and String(ev.payload_summary).find("effect expired: %s" % dot_effect.id) != -1:
            remove_event = ev
    if apply_event == null or tick_event == null or remove_event == null:
        return harness.fail_result("apply_effect lifecycle events missing")
    if turn_end_event == null:
        return harness.fail_result("missing system turn_end event for expire checks")
    if not String(apply_event.cause_event_id).begins_with("effect_event_"):
        return harness.fail_result("apply_effect cause_event_id should point to the upstream effect event")
    if not String(tick_event.cause_event_id).begins_with("effect_event_"):
        return harness.fail_result("tick damage cause_event_id should point to the upstream effect event")
    if remove_event.cause_event_id != _event_id(turn_end_event):
        return harness.fail_result("effect expiration remove log should point to the real system:turn_end anchor")
    if tick_event.cause_event_id == _event_id(tick_event) or remove_event.cause_event_id == _event_id(remove_event):
        return harness.fail_result("effect lifecycle cause_event_id must not point to itself")
    return harness.pass_result()

func _test_apply_effect_none_repeat_skips_log(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var marker_effect = EffectDefinitionScript.new()
    marker_effect.id = "test_none_marker"
    marker_effect.display_name = "None Marker"
    marker_effect.scope = "self"
    marker_effect.duration_mode = "permanent"
    marker_effect.stacking = "none"
    marker_effect.trigger_names = PackedStringArray()
    marker_effect.payloads.clear()
    content_index.register_resource(marker_effect)

    var apply_payload = ApplyEffectPayloadScript.new()
    apply_payload.payload_type = "apply_effect"
    apply_payload.effect_definition_id = marker_effect.id
    var apply_effect = EffectDefinitionScript.new()
    apply_effect.id = "test_apply_none_marker"
    apply_effect.display_name = "Apply None Marker"
    apply_effect.scope = "target"
    apply_effect.duration_mode = "permanent"
    apply_effect.trigger_names = PackedStringArray(["on_cast"])
    apply_effect.payloads.clear()
    apply_effect.payloads.append(apply_payload)
    content_index.register_resource(apply_effect)

    var mark_skill = SkillDefinitionScript.new()
    mark_skill.id = "test_none_marker_skill"
    mark_skill.display_name = "None Marker Skill"
    mark_skill.damage_kind = "none"
    mark_skill.power = 0
    mark_skill.accuracy = 100
    mark_skill.mp_cost = 0
    mark_skill.priority = 0
    mark_skill.targeting = "enemy_active_slot"
    mark_skill.effects_on_cast_ids = PackedStringArray([apply_effect.id])
    content_index.register_resource(mark_skill)
    content_index.units["sample_pyron"].skill_ids[0] = mark_skill.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 244)
    var commands_turn_1: Array = [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": mark_skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    var commands_turn_2: Array = [
        core.service("command_builder").build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": mark_skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_1)
    core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_2)

    var target_unit = battle_state.get_side("P2").get_active_unit()
    var apply_events := 0
    for ev in core.service("battle_logger").event_log:
        if ev.event_type == EventTypesScript.EFFECT_APPLY_EFFECT and String(ev.payload_summary).find(marker_effect.id) != -1:
            apply_events += 1
    if apply_events != 1:
        return harness.fail_result("stacking=none effect should emit exactly one apply log while the instance remains active")
    var marker_count := 0
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == marker_effect.id:
            marker_count += 1
    if marker_count != 1:
        return harness.fail_result("stacking=none effect should keep exactly one runtime instance after repeated apply")
    return harness.pass_result()

func _test_rule_mod_none_repeat_skips_log(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var rule_mod_payload = RuleModPayloadScript.new()
    rule_mod_payload.payload_type = "rule_mod"
    rule_mod_payload.mod_kind = "mp_regen"
    rule_mod_payload.mod_op = "add"
    rule_mod_payload.value = 2
    rule_mod_payload.scope = "target"
    rule_mod_payload.duration_mode = "permanent"
    rule_mod_payload.decrement_on = "turn_end"
    rule_mod_payload.stacking = "none"

    var apply_effect = EffectDefinitionScript.new()
    apply_effect.id = "test_apply_none_rule_mod"
    apply_effect.display_name = "Apply None Rule Mod"
    apply_effect.scope = "target"
    apply_effect.duration_mode = "permanent"
    apply_effect.trigger_names = PackedStringArray(["on_cast"])
    apply_effect.payloads.clear()
    apply_effect.payloads.append(rule_mod_payload)
    content_index.register_resource(apply_effect)

    var mark_skill = SkillDefinitionScript.new()
    mark_skill.id = "test_none_rule_mod_skill"
    mark_skill.display_name = "None Rule Mod Skill"
    mark_skill.damage_kind = "none"
    mark_skill.power = 0
    mark_skill.accuracy = 100
    mark_skill.mp_cost = 0
    mark_skill.priority = 0
    mark_skill.targeting = "enemy_active_slot"
    mark_skill.effects_on_cast_ids = PackedStringArray([apply_effect.id])
    content_index.register_resource(mark_skill)
    content_index.units["sample_pyron"].skill_ids[0] = mark_skill.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 245)
    var commands_turn_1: Array = [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": mark_skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    var commands_turn_2: Array = [
        core.service("command_builder").build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": mark_skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_1)
    core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_2)

    var target_unit = battle_state.get_side("P2").get_active_unit()
    var apply_events := 0
    for ev in core.service("battle_logger").event_log:
        if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and String(ev.payload_summary).find("mp_regen") != -1:
            apply_events += 1
    if apply_events != 1:
        return harness.fail_result("stacking=none rule_mod should emit exactly one apply log while the instance remains active")
    var rule_mod_count := 0
    for rule_mod_instance in target_unit.rule_mod_instances:
        if String(rule_mod_instance.mod_kind) == "mp_regen":
            rule_mod_count += 1
    if rule_mod_count != 1:
        return harness.fail_result("stacking=none rule_mod should keep exactly one runtime instance after repeated apply")
    return harness.pass_result()

func _event_id(log_event) -> String:
    return _helper.event_id(log_event)

func _find_event(event_log: Array, predicate: Callable):
    return _helper.find_event(event_log, predicate)
