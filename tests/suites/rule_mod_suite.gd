extends RefCounted
class_name RuleModSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("rule_mod_paths", failures, Callable(self, "_test_rule_mod_paths").bind(harness))
    runner.run_test("rule_mod_field_scope_paths", failures, Callable(self, "_test_rule_mod_field_scope_paths").bind(harness))
    runner.run_test("invalid_battle_rule_mod_definition", failures, Callable(self, "_test_invalid_battle_rule_mod_definition").bind(harness))
    runner.run_test("rule_mod_skill_legality_enforced", failures, Callable(self, "_test_rule_mod_skill_legality_enforced").bind(harness))

func _test_rule_mod_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 104)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p1_before_mp: int = p1_active.current_mp

    var deny_payload = RuleModPayloadScript.new()
    deny_payload.payload_type = "rule_mod"
    deny_payload.mod_kind = "skill_legality"
    deny_payload.mod_op = "deny"
    deny_payload.value = "sample_strike"
    deny_payload.scope = "self"
    deny_payload.duration_mode = "turns"
    deny_payload.duration = 2
    deny_payload.decrement_on = "turn_start"
    deny_payload.stacking = "replace"
    deny_payload.priority = 10
    if core.rule_mod_service.create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_deny", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create skill_legality rule_mod")

    var regen_payload = RuleModPayloadScript.new()
    regen_payload.payload_type = "rule_mod"
    regen_payload.mod_kind = "mp_regen"
    regen_payload.mod_op = "set"
    regen_payload.value = 0
    regen_payload.scope = "self"
    regen_payload.duration_mode = "turns"
    regen_payload.duration = 1
    regen_payload.decrement_on = "turn_start"
    regen_payload.stacking = "replace"
    regen_payload.priority = 10
    if core.rule_mod_service.create_instance(regen_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_regen", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create mp_regen rule_mod")

    var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if legal_action_set.legal_skill_ids.has("sample_strike"):
        return harness.fail_result("skill_legality rule_mod did not block sample_strike")

    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if p1_active.current_mp != p1_before_mp:
        return harness.fail_result("mp_regen rule_mod did not override turn_start regen")
    var has_remove_log: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == p1_active.unit_instance_id:
            has_remove_log = true
            break
    if not has_remove_log:
        return harness.fail_result("rule_mod remove event missing")

    var baseline_state = harness.build_initialized_battle(core, content_index, sample_factory, 105)
    var modded_state = harness.build_initialized_battle(core, content_index, sample_factory, 105)
    var baseline_commands: Array = [
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(baseline_state, content_index, baseline_commands)
    var baseline_damage = harness.extract_damage_from_log(core.battle_logger.event_log, "P1-A")

    var final_mod_payload = RuleModPayloadScript.new()
    final_mod_payload.payload_type = "rule_mod"
    final_mod_payload.mod_kind = "final_mod"
    final_mod_payload.mod_op = "mul"
    final_mod_payload.value = 2.0
    final_mod_payload.scope = "self"
    final_mod_payload.duration_mode = "turns"
    final_mod_payload.duration = 2
    final_mod_payload.decrement_on = "turn_end"
    final_mod_payload.stacking = "replace"
    final_mod_payload.priority = 10
    var modded_p1_active = modded_state.get_side("P1").get_active_unit()
    if core.rule_mod_service.create_instance(final_mod_payload, {"scope": "unit", "id": modded_p1_active.unit_instance_id}, modded_state, "test_rule_mod_final", 0, modded_p1_active.base_speed) == null:
        return harness.fail_result("failed to create final_mod rule_mod")
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(modded_state, content_index, baseline_commands)
    var modded_damage = harness.extract_damage_from_log(core.battle_logger.event_log, "P1-A")
    if baseline_damage <= 0 or modded_damage <= baseline_damage:
        return harness.fail_result("final_mod rule_mod did not increase damage")
    return harness.pass_result()

func _test_rule_mod_field_scope_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 115)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p1_active.regen_per_turn = 0
    p2_active.regen_per_turn = 0
    p1_active.current_mp = 0
    p2_active.current_mp = 0

    var field_regen_payload = RuleModPayloadScript.new()
    field_regen_payload.payload_type = "rule_mod"
    field_regen_payload.mod_kind = "mp_regen"
    field_regen_payload.mod_op = "add"
    field_regen_payload.value = 5
    field_regen_payload.scope = "field"
    field_regen_payload.duration_mode = "turns"
    field_regen_payload.duration = 1
    field_regen_payload.decrement_on = "turn_start"
    field_regen_payload.stacking = "replace"
    field_regen_payload.priority = 5
    if core.rule_mod_service.create_instance(field_regen_payload, {"scope": "field", "id": "field"}, battle_state, "test_field_regen_mod", 0, 0) == null:
        return harness.fail_result("failed to create field-scope mp_regen rule_mod")
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if p1_active.current_mp != 5 or p2_active.current_mp != 5:
        return harness.fail_result("field-scope mp_regen rule_mod did not apply to both active units")
    var has_field_remove_log: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == "field":
            has_field_remove_log = true
            break
    if not has_field_remove_log:
        return harness.fail_result("field-scope rule_mod remove event missing")

    var baseline_state = harness.build_initialized_battle(core, content_index, sample_factory, 116)
    var modded_state = harness.build_initialized_battle(core, content_index, sample_factory, 116)
    var baseline_commands: Array = [
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(baseline_state, content_index, baseline_commands)
    var baseline_damage = harness.extract_damage_from_log(core.battle_logger.event_log, "P1-A")
    var field_final_mod_payload = RuleModPayloadScript.new()
    field_final_mod_payload.payload_type = "rule_mod"
    field_final_mod_payload.mod_kind = "final_mod"
    field_final_mod_payload.mod_op = "mul"
    field_final_mod_payload.value = 2.0
    field_final_mod_payload.scope = "field"
    field_final_mod_payload.duration_mode = "turns"
    field_final_mod_payload.duration = 2
    field_final_mod_payload.decrement_on = "turn_end"
    field_final_mod_payload.stacking = "replace"
    field_final_mod_payload.priority = 10
    if core.rule_mod_service.create_instance(field_final_mod_payload, {"scope": "field", "id": "field"}, modded_state, "test_field_final_mod", 0, 0) == null:
        return harness.fail_result("failed to create field-scope final_mod rule_mod")
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(modded_state, content_index, baseline_commands)
    var modded_damage = harness.extract_damage_from_log(core.battle_logger.event_log, "P1-A")
    if baseline_damage <= 0 or modded_damage <= baseline_damage:
        return harness.fail_result("field-scope final_mod rule_mod did not increase damage")

    var legality_state = harness.build_initialized_battle(core, content_index, sample_factory, 117)
    var field_legality_payload = RuleModPayloadScript.new()
    field_legality_payload.payload_type = "rule_mod"
    field_legality_payload.mod_kind = "skill_legality"
    field_legality_payload.mod_op = "deny"
    field_legality_payload.value = "sample_strike"
    field_legality_payload.scope = "field"
    field_legality_payload.duration_mode = "turns"
    field_legality_payload.duration = 2
    field_legality_payload.decrement_on = "turn_start"
    field_legality_payload.stacking = "replace"
    field_legality_payload.priority = 10
    if core.rule_mod_service.create_instance(field_legality_payload, {"scope": "field", "id": "field"}, legality_state, "test_field_skill_legality", 0, 0) == null:
        return harness.fail_result("failed to create field-scope skill_legality rule_mod")
    var legal_action_set = core.legal_action_service.get_legal_actions(legality_state, "P1", content_index)
    if legal_action_set.legal_skill_ids.has("sample_strike"):
        return harness.fail_result("field-scope skill_legality rule_mod did not block sample_strike")

    var invalid_scope_payload = RuleModPayloadScript.new()
    invalid_scope_payload.payload_type = "rule_mod"
    invalid_scope_payload.mod_kind = "final_mod"
    invalid_scope_payload.mod_op = "mul"
    invalid_scope_payload.value = 1.1
    invalid_scope_payload.scope = "field"
    invalid_scope_payload.duration_mode = "turns"
    invalid_scope_payload.duration = 1
    invalid_scope_payload.decrement_on = "turn_start"
    invalid_scope_payload.stacking = "replace"
    var invalid_owner = legality_state.get_side("P1").get_active_unit()
    if core.rule_mod_service.create_instance(invalid_scope_payload, {"scope": "unit", "id": invalid_owner.unit_instance_id}, legality_state, "test_invalid_field_owner", 0, invalid_owner.base_speed) != null:
        return harness.fail_result("invalid field owner binding should fail")
    if core.rule_mod_service.last_error_code != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
        return harness.fail_result("invalid field owner binding should return invalid_rule_mod_definition")
    return harness.pass_result()

func _test_invalid_battle_rule_mod_definition(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var invalid_payload = RuleModPayloadScript.new()
    invalid_payload.payload_type = "rule_mod"
    invalid_payload.mod_kind = "final_mod"
    invalid_payload.mod_op = "mul"
    invalid_payload.value = 1.5
    invalid_payload.scope = "self"
    invalid_payload.duration_mode = "turns"
    invalid_payload.duration = 1
    invalid_payload.decrement_on = ""
    invalid_payload.stacking = "replace"
    var invalid_effect = EffectDefinitionScript.new()
    invalid_effect.id = "test_invalid_rule_mod_effect"
    invalid_effect.display_name = "Invalid Rule Mod Effect"
    invalid_effect.scope = "self"
    invalid_effect.trigger_names = PackedStringArray(["on_cast"])
    invalid_effect.payloads.clear()
    invalid_effect.payloads.append(invalid_payload)
    var invalid_skill = SkillDefinitionScript.new()
    invalid_skill.id = "test_invalid_rule_mod_skill"
    invalid_skill.display_name = "Invalid Rule Mod Skill"
    invalid_skill.damage_kind = "none"
    invalid_skill.power = 0
    invalid_skill.accuracy = 100
    invalid_skill.mp_cost = 0
    invalid_skill.priority = 0
    invalid_skill.targeting = "self"
    invalid_skill.effects_on_cast_ids = PackedStringArray([invalid_effect.id])
    content_index.register_resource(invalid_effect)
    content_index.register_resource(invalid_skill)
    var p1_def = content_index.units["sample_pyron"]
    if not p1_def.skill_ids.has(invalid_skill.id):
        p1_def.skill_ids.append(invalid_skill.id)

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 106)
    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": invalid_skill.id,
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
    if not battle_state.battle_result.finished:
        return harness.fail_result("invalid_battle should finish battle immediately")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
        return harness.fail_result("invalid_battle reason mismatch: %s" % str(battle_state.battle_result.reason))
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
            return harness.pass_result()
    return harness.fail_result("invalid_battle log event missing")

func _test_rule_mod_skill_legality_enforced(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 107)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    if p1_active == null:
        return harness.fail_result("P1 active unit missing")

    var deny_payload = RuleModPayloadScript.new()
    deny_payload.payload_type = "rule_mod"
    deny_payload.mod_kind = "skill_legality"
    deny_payload.mod_op = "deny"
    deny_payload.value = "sample_strike"
    deny_payload.scope = "self"
    deny_payload.duration_mode = "turns"
    deny_payload.duration = 2
    deny_payload.decrement_on = "turn_start"
    deny_payload.stacking = "replace"
    deny_payload.priority = 10
    if core.rule_mod_service.create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_skill_legality_gate", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create skill_legality deny instance")

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
    if not battle_state.battle_result.finished:
        return harness.fail_result("illegal manual command should fail-fast")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return harness.fail_result("expected invalid_command_payload, got %s" % str(battle_state.battle_result.reason))
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
            return harness.pass_result()
    return harness.fail_result("missing invalid_battle log for illegal command")
