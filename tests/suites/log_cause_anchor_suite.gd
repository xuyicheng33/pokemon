extends RefCounted
class_name LogCauseAnchorSuite

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const LogCauseTestHelperScript := preload("res://tests/support/log_cause_test_helper.gd")

var _helper = LogCauseTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("system_anchor_effect_cause_contract", failures, Callable(self, "_test_system_anchor_effect_cause_contract").bind(harness))
    runner.run_test("apply_field_creator_non_action_chain", failures, Callable(self, "_test_apply_field_creator_non_action_chain").bind(harness))
func _test_system_anchor_effect_cause_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 219)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    if p1_active == null or p2_active == null:
        return harness.fail_result("missing active units")

    var expire_payload = RuleModPayloadScript.new()
    expire_payload.payload_type = "rule_mod"
    expire_payload.mod_kind = "mp_regen"
    expire_payload.mod_op = "set"
    expire_payload.value = 0
    expire_payload.scope = "self"
    expire_payload.duration_mode = "turns"
    expire_payload.duration = 1
    expire_payload.decrement_on = "turn_start"
    expire_payload.stacking = "replace"
    expire_payload.priority = 5
    if core.rule_mod_service.create_instance(expire_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_turn_start_expire_rule_mod", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create turn_start expiring rule_mod")

    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_field_call",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
        }),
        core.command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    var turn_start_events := _find_events(core.battle_logger.event_log, func(ev): return ev.event_type == EventTypesScript.SYSTEM_TURN_START)
    var turn_end_events := _find_events(core.battle_logger.event_log, func(ev): return ev.event_type == EventTypesScript.SYSTEM_TURN_END)
    if turn_start_events.size() < 2 or turn_end_events.size() < 2:
        return harness.fail_result("missing turn anchor events for cause contract checks")
    var first_turn_start = turn_start_events[0]
    var second_turn_start = turn_start_events[1]
    var second_turn_end = turn_end_events[1]
    var regen_event = _find_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD \
        and ev.source_instance_id == "system:turn_start" \
        and ev.target_instance_id == p2_active.unit_instance_id
    )
    var rule_mod_remove_event = _find_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE \
        and ev.target_instance_id == p1_active.unit_instance_id
    )
    var field_expire_event = _find_event(core.battle_logger.event_log, func(ev): return ev.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE)
    if regen_event == null or rule_mod_remove_event == null or field_expire_event == null:
        return harness.fail_result("missing turn_start/turn_end effect logs for cause contract checks")
    if regen_event.cause_event_id != _event_id(second_turn_start):
        return harness.fail_result("turn_start regen cause_event_id should point to the real system:turn_start anchor")
    if rule_mod_remove_event.cause_event_id != _event_id(first_turn_start):
        return harness.fail_result("rule_mod remove cause_event_id should point to the real system:turn_start anchor")
    if field_expire_event.cause_event_id != _event_id(second_turn_end):
        return harness.fail_result("field expire cause_event_id should point to the real system:turn_end anchor")
    if regen_event.cause_event_id == _event_id(regen_event) \
    or rule_mod_remove_event.cause_event_id == _event_id(rule_mod_remove_event) \
    or field_expire_event.cause_event_id == _event_id(field_expire_event):
        return harness.fail_result("system-anchor effect events must not point cause_event_id to themselves")
    return harness.pass_result()

func _test_apply_field_creator_non_action_chain(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var field_def = FieldDefinitionScript.new()
    field_def.id = "test_non_action_field"
    field_def.display_name = "Non Action Field"
    field_def.effect_ids = PackedStringArray()
    content_index.register_resource(field_def)

    var apply_field_payload = ApplyFieldPayloadScript.new()
    apply_field_payload.payload_type = "apply_field"
    apply_field_payload.field_definition_id = field_def.id
    var apply_field_effect = EffectDefinitionScript.new()
    apply_field_effect.id = "test_non_action_apply_field_effect"
    apply_field_effect.display_name = "Non Action Apply Field"
    apply_field_effect.scope = "self"
    apply_field_effect.trigger_names = PackedStringArray(["on_enter"])
    apply_field_effect.duration_mode = "turns"
    apply_field_effect.duration = 2
    apply_field_effect.payloads.clear()
    apply_field_effect.payloads.append(apply_field_payload)
    content_index.register_resource(apply_field_effect)

    var apply_field_passive = PassiveSkillDefinitionScript.new()
    apply_field_passive.id = "test_non_action_apply_field_passive"
    apply_field_passive.display_name = "Non Action Apply Field Passive"
    apply_field_passive.trigger_names = PackedStringArray(["on_enter"])
    apply_field_passive.effect_ids = PackedStringArray([apply_field_effect.id])
    content_index.register_resource(apply_field_passive)
    content_index.units["sample_pyron"].passive_skill_id = apply_field_passive.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 218)
    if battle_state.field_state == null:
        return harness.fail_result("on_enter apply_field should create field_state")
    var p1_active = battle_state.get_side("P1").get_active_unit()
    if p1_active == null:
        return harness.fail_result("missing P1 active unit")
    if battle_state.field_state.creator != p1_active.unit_instance_id:
        return harness.fail_result("field creator should use effect owner in non-action chain")
    if battle_state.field_state.source_instance_id.is_empty():
        return harness.fail_result("field source_instance_id should not be empty")
    return harness.pass_result()

func _event_id(log_event) -> String:
    return _helper.event_id(log_event)

func _find_event(event_log: Array, predicate: Callable):
    return _helper.find_event(event_log, predicate)

func _find_events(event_log: Array, predicate: Callable) -> Array:
    return _helper.find_events(event_log, predicate)
