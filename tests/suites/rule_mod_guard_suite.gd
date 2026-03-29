extends RefCounted
class_name RuleModGuardSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("invalid_battle_rule_mod_definition", failures, Callable(self, "_test_invalid_battle_rule_mod_definition").bind(harness))
    runner.run_test("rule_mod_skill_legality_enforced", failures, Callable(self, "_test_rule_mod_skill_legality_enforced").bind(harness))
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
        p1_def.skill_ids[0] = invalid_skill.id

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
