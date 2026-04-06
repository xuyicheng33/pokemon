extends "res://tests/suites/extension_targeting_accuracy/base.gd"
const BaseSuiteScript := preload("res://tests/suites/extension_targeting_accuracy/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("incoming_accuracy_contract", failures, Callable(self, "_test_incoming_accuracy_contract").bind(harness))

func _test_incoming_accuracy_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 909)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    if p1_active == null or p2_active == null:
        return harness.fail_result("missing active units for incoming_accuracy contract")

    var incoming_payload = RuleModPayloadScript.new()
    incoming_payload.payload_type = "rule_mod"
    incoming_payload.mod_kind = "incoming_accuracy"
    incoming_payload.mod_op = "add"
    incoming_payload.value = -10
    incoming_payload.scope = "self"
    incoming_payload.duration_mode = "permanent"
    incoming_payload.decrement_on = "turn_end"
    incoming_payload.stacking = "none"
    if core.service("rule_mod_service").create_instance(incoming_payload, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "test_incoming_accuracy_down", 0, p2_active.base_speed) == null:
        return harness.fail_result("failed to create incoming_accuracy rule_mod")

    var accuracy_skill = SkillDefinitionScript.new()
    accuracy_skill.id = "test_incoming_accuracy_skill"
    accuracy_skill.display_name = "Incoming Accuracy Skill"
    accuracy_skill.damage_kind = "none"
    accuracy_skill.power = 0
    accuracy_skill.accuracy = 95
    accuracy_skill.mp_cost = 0
    accuracy_skill.priority = 0
    accuracy_skill.targeting = "enemy_active_slot"
    content_index.register_resource(accuracy_skill)

    var command = core.service("command_builder").build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": accuracy_skill.id,
    })
    command.actor_id = p1_active.unit_instance_id
    var hit_info = core.service("action_cast_service").resolve_hit(command, accuracy_skill, p2_active, battle_state, content_index)
    if abs(float(hit_info.get("hit_rate", -1.0)) - 0.85) > 0.0001:
        return harness.fail_result("incoming_accuracy should reduce 95 accuracy enemy_active skill to 85")

    accuracy_skill.accuracy = 100
    var guaranteed_hit_info = core.service("action_cast_service").resolve_hit(command, accuracy_skill, p2_active, battle_state, content_index)
    if guaranteed_hit_info.get("hit_roll", "not-null") != null or abs(float(guaranteed_hit_info.get("hit_rate", -1.0)) - 1.0) > 0.0001:
        return harness.fail_result("incoming_accuracy must not affect guaranteed-hit actions")

    accuracy_skill.accuracy = 95
    accuracy_skill.targeting = "self"
    var self_target_hit_info = core.service("action_cast_service").resolve_hit(command, accuracy_skill, p1_active, battle_state, content_index)
    if abs(float(self_target_hit_info.get("hit_rate", -1.0)) - 0.95) > 0.0001:
        return harness.fail_result("incoming_accuracy must not affect self-target actions")
    return harness.pass_result()
