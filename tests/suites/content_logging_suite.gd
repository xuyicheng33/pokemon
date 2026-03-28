extends RefCounted
class_name ContentLoggingSuite

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("log_contract_semantics", failures, Callable(self, "_test_log_contract_semantics").bind(harness))
    runner.run_test("apply_effect_lifecycle_chain", failures, Callable(self, "_test_apply_effect_lifecycle_chain").bind(harness))
    runner.run_test("system_anchor_effect_cause_contract", failures, Callable(self, "_test_system_anchor_effect_cause_contract").bind(harness))
    runner.run_test("content_validation_failures", failures, Callable(self, "_test_content_validation_failures").bind(harness))
    runner.run_test("content_validation_new_constraints", failures, Callable(self, "_test_content_validation_new_constraints").bind(harness))
    runner.run_test("on_receive_forbidden_in_content", failures, Callable(self, "_test_on_receive_forbidden_in_content").bind(harness))
    runner.run_test("apply_field_creator_non_action_chain", failures, Callable(self, "_test_apply_field_creator_non_action_chain").bind(harness))

func _test_log_contract_semantics(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var replay_output = core.replay_runner.run_replay(sample_factory.build_demo_replay_input(core.command_builder))
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
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": dot_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)

    var turn_end_event = _find_event(core.battle_logger.event_log, func(ev): return ev.event_type == EventTypesScript.SYSTEM_TURN_END)
    var apply_event = null
    var tick_event = null
    var remove_event = null
    for ev in core.battle_logger.event_log:
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
    if regen_event.cause_event_id != _event_id(first_turn_start):
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

func _test_content_validation_failures(harness) -> Dictionary:
    var content_index = BattleContentIndexScript.new()

    var bad_skill = SkillDefinitionScript.new()
    bad_skill.id = "bad_skill"
    bad_skill.display_name = "Bad Skill"
    bad_skill.damage_kind = "bad_kind"
    bad_skill.accuracy = 120
    bad_skill.mp_cost = -1
    bad_skill.targeting = "bad_target"
    bad_skill.priority = 9
    content_index.register_resource(bad_skill)

    var duplicate_skill_a = SkillDefinitionScript.new()
    duplicate_skill_a.id = "duplicate_skill"
    duplicate_skill_a.display_name = "Duplicate Skill A"
    duplicate_skill_a.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
    content_index.register_resource(duplicate_skill_a)

    var duplicate_skill_b = SkillDefinitionScript.new()
    duplicate_skill_b.id = "duplicate_skill"
    duplicate_skill_b.display_name = "Duplicate Skill B"
    duplicate_skill_b.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
    content_index.register_resource(duplicate_skill_b)

    var bad_unit = UnitDefinitionScript.new()
    bad_unit.id = "bad_unit"
    bad_unit.display_name = "Bad Unit"
    bad_unit.skill_ids = PackedStringArray(["missing_skill"])
    bad_unit.ultimate_skill_id = "missing_ultimate"
    content_index.register_resource(bad_unit)

    var bad_rule_mod = RuleModPayloadScript.new()
    bad_rule_mod.payload_type = "rule_mod"
    bad_rule_mod.mod_kind = "bad_kind"
    bad_rule_mod.mod_op = "bad_op"
    bad_rule_mod.scope = "self"
    bad_rule_mod.duration_mode = "turns"
    bad_rule_mod.duration = 1
    bad_rule_mod.decrement_on = "turn_start"
    bad_rule_mod.stacking = "none"
    bad_rule_mod.priority = 0
    var bad_effect = EffectDefinitionScript.new()
    bad_effect.id = "bad_effect"
    bad_effect.display_name = "Bad Effect"
    bad_effect.scope = "self"
    bad_effect.duration_mode = "permanent"
    bad_effect.trigger_names = PackedStringArray(["on_cast"])
    bad_effect.payloads.clear()
    bad_effect.payloads.append(bad_rule_mod)
    content_index.register_resource(bad_effect)

    var bad_resource_payload = ResourceModPayloadScript.new()
    bad_resource_payload.payload_type = "resource_mod"
    bad_resource_payload.resource_key = "energy"
    bad_resource_payload.amount = 2
    var bad_resource_effect = EffectDefinitionScript.new()
    bad_resource_effect.id = "bad_resource_effect"
    bad_resource_effect.display_name = "Bad Resource Effect"
    bad_resource_effect.scope = "self"
    bad_resource_effect.duration_mode = "permanent"
    bad_resource_effect.trigger_names = PackedStringArray(["on_cast"])
    bad_resource_effect.payloads.clear()
    bad_resource_effect.payloads.append(bad_resource_payload)
    content_index.register_resource(bad_resource_effect)

    var bad_stat_payload = StatModPayloadScript.new()
    bad_stat_payload.payload_type = "stat_mod"
    bad_stat_payload.stat_name = "luck"
    bad_stat_payload.stage_delta = 1
    var bad_stat_effect = EffectDefinitionScript.new()
    bad_stat_effect.id = "bad_stat_effect"
    bad_stat_effect.display_name = "Bad Stat Effect"
    bad_stat_effect.scope = "self"
    bad_stat_effect.duration_mode = "permanent"
    bad_stat_effect.trigger_names = PackedStringArray(["on_cast"])
    bad_stat_effect.payloads.clear()
    bad_stat_effect.payloads.append(bad_stat_payload)
    content_index.register_resource(bad_stat_effect)

    var errors: Array = content_index.validate_snapshot()
    if errors.is_empty():
        return harness.fail_result("content validator did not report failures")
    var has_priority_error: bool = false
    var has_rule_mod_error: bool = false
    var has_missing_ref: bool = false
    var has_accuracy_error: bool = false
    var has_mp_cost_error: bool = false
    var has_duplicate_id_error: bool = false
    var has_resource_key_error: bool = false
    var has_stat_name_error: bool = false
    for error_msg in errors:
        var msg = str(error_msg)
        if msg.find("priority out of range") != -1:
            has_priority_error = true
        if msg.find("rule_mod invalid") != -1:
            has_rule_mod_error = true
        if msg.find("missing skill") != -1:
            has_missing_ref = true
        if msg.find("accuracy out of range") != -1:
            has_accuracy_error = true
        if msg.find("mp_cost must be >= 0") != -1:
            has_mp_cost_error = true
        if msg.find("duplicated id") != -1:
            has_duplicate_id_error = true
        if msg.find("invalid resource_key") != -1:
            has_resource_key_error = true
        if msg.find("invalid stat_name") != -1:
            has_stat_name_error = true
    if not (has_priority_error and has_rule_mod_error and has_missing_ref and has_accuracy_error and has_mp_cost_error and has_duplicate_id_error and has_resource_key_error and has_stat_name_error):
        return harness.fail_result("content validation errors missing expected categories")
    return harness.pass_result()

func _test_content_validation_new_constraints(harness) -> Dictionary:
    var content_index = BattleContentIndexScript.new()

    var regular_ok = SkillDefinitionScript.new()
    regular_ok.id = "regular_ok"
    regular_ok.display_name = "Regular OK"
    regular_ok.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
    regular_ok.priority = 0
    content_index.register_resource(regular_ok)

    var regular_bad = SkillDefinitionScript.new()
    regular_bad.id = "regular_bad_priority"
    regular_bad.display_name = "Regular Bad Priority"
    regular_bad.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
    regular_bad.priority = 5
    content_index.register_resource(regular_bad)

    var ultimate_bad = SkillDefinitionScript.new()
    ultimate_bad.id = "ultimate_bad_priority"
    ultimate_bad.display_name = "Ultimate Bad Priority"
    ultimate_bad.targeting = ContentSchemaScript.TARGET_ENEMY_ACTIVE
    ultimate_bad.priority = 0
    content_index.register_resource(ultimate_bad)

    var slot_bad_unit = UnitDefinitionScript.new()
    slot_bad_unit.id = "slot_bad_unit"
    slot_bad_unit.display_name = "Slot Bad Unit"
    slot_bad_unit.skill_ids = PackedStringArray(["regular_ok", "regular_bad_priority"])
    slot_bad_unit.ultimate_skill_id = "ultimate_bad_priority"
    content_index.register_resource(slot_bad_unit)

    var regular_priority_bad_unit = UnitDefinitionScript.new()
    regular_priority_bad_unit.id = "regular_priority_bad_unit"
    regular_priority_bad_unit.display_name = "Regular Priority Bad Unit"
    regular_priority_bad_unit.skill_ids = PackedStringArray(["regular_bad_priority", "regular_ok", "regular_ok"])
    regular_priority_bad_unit.ultimate_skill_id = ""
    content_index.register_resource(regular_priority_bad_unit)

    var ultimate_duplicate_unit = UnitDefinitionScript.new()
    ultimate_duplicate_unit.id = "ultimate_duplicate_unit"
    ultimate_duplicate_unit.display_name = "Ultimate Duplicate Unit"
    ultimate_duplicate_unit.skill_ids = PackedStringArray(["ultimate_bad_priority", "regular_ok", "regular_ok"])
    ultimate_duplicate_unit.ultimate_skill_id = "ultimate_bad_priority"
    content_index.register_resource(ultimate_duplicate_unit)

    content_index.register_resource(_build_dynamic_formula_effect(
        "invalid_dynamic_formula_effect",
        "self",
        PackedInt32Array([20, 10]),
        PackedFloat32Array([5.0])
    ))
    content_index.register_resource(_build_dynamic_formula_effect(
        "invalid_field_dynamic_formula_effect",
        "field",
        PackedInt32Array([20]),
        PackedFloat32Array([5.0])
    ))

    var snapshot_errors: Array = content_index.validate_snapshot()
    if snapshot_errors.is_empty():
        return harness.fail_result("new content constraints should report validation failures")

    var has_regular_priority_error: bool = false
    var has_ultimate_priority_error: bool = false
    var has_slot_error: bool = false
    var has_ultimate_in_regular_error: bool = false
    var has_dynamic_formula_error: bool = false
    var has_dynamic_formula_scope_error: bool = false
    for error_msg in snapshot_errors:
        var msg = str(error_msg)
        has_regular_priority_error = has_regular_priority_error or msg.find("used in unit.skill_ids must have priority in -2..2") != -1
        has_ultimate_priority_error = has_ultimate_priority_error or msg.find("used as ultimate must have priority +5 or -5") != -1
        has_slot_error = has_slot_error or msg.find("skill_ids must contain exactly 3 entries") != -1
        has_ultimate_in_regular_error = has_ultimate_in_regular_error or msg.find("used as ultimate must not appear in any unit.skill_ids") != -1
        has_dynamic_formula_error = has_dynamic_formula_error or msg.find("dynamic_value_thresholds/dynamic_value_outputs size mismatch") != -1 or msg.find("dynamic_value_thresholds must be strictly ascending") != -1
        has_dynamic_formula_scope_error = has_dynamic_formula_scope_error or msg.find("dynamic value formula is not allowed for field scope") != -1
    if not (has_regular_priority_error and has_ultimate_priority_error and has_slot_error and has_ultimate_in_regular_error and has_dynamic_formula_error and has_dynamic_formula_scope_error):
        return harness.fail_result("new content validation constraints missing expected failures")

    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var runtime_content = harness.build_loaded_content_index(sample_factory)
    var duplicate_item = PassiveItemDefinitionScript.new()
    duplicate_item.id = "duplicate_item_for_setup_validation"
    duplicate_item.display_name = "Duplicate Item"
    runtime_content.register_resource(duplicate_item)
    runtime_content.units["sample_pyron"].passive_item_id = duplicate_item.id
    runtime_content.units["sample_mossaur"].passive_item_id = duplicate_item.id
    var battle_setup = sample_factory.build_sample_setup()
    var setup_errors: Array = runtime_content.validate_setup(battle_setup)
    var has_duplicate_item_error: bool = false
    for error_msg in setup_errors:
        if str(error_msg).find("duplicated passive_item_id") != -1:
            has_duplicate_item_error = true
            break
    if not has_duplicate_item_error:
        return harness.fail_result("battle setup should reject duplicate passive items on same side")
    return harness.pass_result()

func _test_on_receive_forbidden_in_content(harness) -> Dictionary:
    var content_index = BattleContentIndexScript.new()
    var effect = EffectDefinitionScript.new()
    effect.id = "test_on_receive_forbidden_effect"
    effect.display_name = "On Receive Forbidden Effect"
    effect.scope = "self"
    effect.trigger_names = PackedStringArray(["on_hit"])
    content_index.register_resource(effect)

    var passive_item = PassiveItemDefinitionScript.new()
    passive_item.id = "test_on_receive_forbidden_item"
    passive_item.display_name = "On Receive Forbidden Item"
    passive_item.on_receive_effect_ids = PackedStringArray([effect.id])
    content_index.register_resource(passive_item)

    var errors: Array = content_index.validate_snapshot()
    if errors.is_empty():
        return harness.fail_result("on_receive_effect_ids should fail-fast at content validation")
    for error_msg in errors:
        if str(error_msg).find("on_receive_effect_ids is disabled") != -1:
            return harness.pass_result()
    return harness.fail_result("missing disabled on_receive_effect_ids validation error")

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
    return "%s:%d" % [log_event.event_chain_id, log_event.event_step_id]

func _build_dynamic_formula_effect(effect_id: String, scope: String, thresholds: PackedInt32Array, outputs: PackedFloat32Array):
    var payload = RuleModPayloadScript.new()
    payload.mod_kind = "mp_regen"
    payload.mod_op = "set"
    payload.scope = scope
    payload.duration_mode = "turns"
    payload.duration = 1
    payload.decrement_on = "turn_start"
    payload.stacking = "replace"
    payload.dynamic_value_formula = ContentSchemaScript.RULE_MOD_VALUE_FORMULA_MATCHUP_BST_GAP_BAND
    payload.dynamic_value_thresholds = thresholds
    payload.dynamic_value_outputs = outputs
    var effect = EffectDefinitionScript.new()
    effect.id = effect_id
    effect.scope = scope
    effect.trigger_names = PackedStringArray(["on_cast"])
    effect.payloads.clear()
    effect.payloads.append(payload)
    return effect
func _find_event(event_log: Array, predicate: Callable):
    for ev in event_log:
        if predicate.call(ev):
            return ev
    return null

func _find_events(event_log: Array, predicate: Callable) -> Array:
    var matched: Array = []
    for ev in event_log:
        if predicate.call(ev):
            matched.append(ev)
    return matched
