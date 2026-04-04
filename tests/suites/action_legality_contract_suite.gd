extends RefCounted
class_name ActionLegalityContractSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("action_legality_contract", failures, Callable(self, "_test_action_legality_contract").bind(harness))
    runner.run_test("action_legality_managed_action_matrix_contract", failures, Callable(self, "_test_action_legality_managed_action_matrix_contract").bind(harness))
    runner.run_test("action_legality_unknown_action_type_reports_contract", failures, Callable(self, "_test_action_legality_unknown_action_type_reports_contract").bind(harness))
func _test_action_legality_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 904)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    if p1_active == null:
        return harness.fail_result("missing P1 active unit")

    var deny_all = RuleModPayloadScript.new()
    deny_all.payload_type = "rule_mod"
    deny_all.mod_kind = "action_legality"
    deny_all.mod_op = "deny"
    deny_all.value = "all"
    deny_all.scope = "self"
    deny_all.duration_mode = "turns"
    deny_all.duration = 2
    deny_all.decrement_on = "turn_start"
    deny_all.stacking = "replace"
    deny_all.priority = 10
    if core.service("rule_mod_service").create_instance(deny_all, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_action_legality_deny_all", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create action_legality deny all instance")
    var denied_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
    if denied_actions.wait_allowed != true or denied_actions.forced_command_type != "":
        return harness.fail_result("deny all should leave wait legal and must not fall back to resource_forced_default")
    if not core.service("rule_mod_service").is_action_allowed(battle_state, p1_active.unit_instance_id, CommandTypesScript.RESOURCE_FORCED_DEFAULT):
        return harness.fail_result("resource_forced_default should stay outside action_legality control")
    if not core.service("rule_mod_service").is_action_allowed(battle_state, p1_active.unit_instance_id, CommandTypesScript.SURRENDER):
        return harness.fail_result("surrender should stay outside action_legality control")
    if not denied_actions.legal_skill_ids.is_empty() or not denied_actions.legal_ultimate_ids.is_empty() or not denied_actions.legal_switch_target_public_ids.is_empty():
        return harness.fail_result("deny all should block skills, ultimates, and switches")

    var allow_switch = RuleModPayloadScript.new()
    allow_switch.payload_type = "rule_mod"
    allow_switch.mod_kind = "action_legality"
    allow_switch.mod_op = "allow"
    allow_switch.value = "switch"
    allow_switch.scope = "self"
    allow_switch.duration_mode = "turns"
    allow_switch.duration = 2
    allow_switch.decrement_on = "turn_start"
    allow_switch.stacking = "replace"
    allow_switch.priority = 9
    if core.service("rule_mod_service").create_instance(allow_switch, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_action_legality_allow_switch", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create action_legality allow switch instance")
    var allow_switch_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
    if allow_switch_actions.legal_switch_target_public_ids != PackedStringArray(["P1-B", "P1-C"]):
        return harness.fail_result("deny all + allow switch should re-open switch targets only")

    var selective_state = harness.build_initialized_battle(core, content_index, sample_factory, 905)
    var selective_actor = selective_state.get_side("P1").get_active_unit()
    var deny_skill = RuleModPayloadScript.new()
    deny_skill.payload_type = "rule_mod"
    deny_skill.mod_kind = "action_legality"
    deny_skill.mod_op = "deny"
    deny_skill.value = "skill"
    deny_skill.scope = "self"
    deny_skill.duration_mode = "turns"
    deny_skill.duration = 2
    deny_skill.decrement_on = "turn_start"
    deny_skill.stacking = "replace"
    if core.service("rule_mod_service").create_instance(deny_skill, {"scope": "unit", "id": selective_actor.unit_instance_id}, selective_state, "test_action_legality_deny_skill", 0, selective_actor.base_speed) == null:
        return harness.fail_result("failed to create action_legality deny skill instance")
    var allow_specific = RuleModPayloadScript.new()
    allow_specific.payload_type = "rule_mod"
    allow_specific.mod_kind = "action_legality"
    allow_specific.mod_op = "allow"
    allow_specific.value = "sample_strike"
    allow_specific.scope = "self"
    allow_specific.duration_mode = "turns"
    allow_specific.duration = 2
    allow_specific.decrement_on = "turn_start"
    allow_specific.stacking = "replace"
    allow_specific.priority = -1
    if core.service("rule_mod_service").create_instance(allow_specific, {"scope": "unit", "id": selective_actor.unit_instance_id}, selective_state, "test_action_legality_allow_specific", 0, selective_actor.base_speed) == null:
        return harness.fail_result("failed to create action_legality allow specific instance")
    var selective_actions = core.service("legal_action_service").get_legal_actions(selective_state, "P1", content_index)
    if not selective_actions.legal_skill_ids.has("sample_strike") or selective_actions.legal_skill_ids.has("sample_field_call"):
        return harness.fail_result("deny skill + allow sample_strike should keep only the explicitly re-opened skill")

    var lock_payload = RuleModPayloadScript.new()
    lock_payload.payload_type = "rule_mod"
    lock_payload.mod_kind = "action_legality"
    lock_payload.mod_op = "deny"
    lock_payload.value = "all"
    lock_payload.scope = "target"
    lock_payload.duration_mode = "turns"
    lock_payload.duration = 1
    lock_payload.decrement_on = "turn_end"
    lock_payload.stacking = "replace"
    var lock_effect = EffectDefinitionScript.new()
    lock_effect.id = "test_action_lock_effect"
    lock_effect.display_name = "Action Lock Effect"
    lock_effect.scope = "target"
    lock_effect.trigger_names = PackedStringArray(["on_hit"])
    lock_effect.payloads.append(lock_payload)
    content_index.register_resource(lock_effect)
    var lock_skill = SkillDefinitionScript.new()
    lock_skill.id = "test_action_lock_skill"
    lock_skill.display_name = "Action Lock Skill"
    lock_skill.damage_kind = "none"
    lock_skill.power = 0
    lock_skill.accuracy = 100
    lock_skill.mp_cost = 0
    lock_skill.priority = 0
    lock_skill.targeting = "enemy_active_slot"
    lock_skill.effects_on_hit_ids = PackedStringArray([lock_effect.id])
    content_index.register_resource(lock_skill)
    var queue_lock_state = harness.build_initialized_battle(core, content_index, sample_factory, 906)
    var queue_lock_p1 = queue_lock_state.get_side("P1").get_active_unit()
    var queue_lock_p2 = queue_lock_state.get_side("P2").get_active_unit()
    queue_lock_p1.regular_skill_ids[0] = lock_skill.id
    queue_lock_p1.base_speed = 999
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(queue_lock_state, content_index, [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": lock_skill.id,
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    if not _has_event(core.service("battle_logger").event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START \
            and ev.target_instance_id == queue_lock_p2.unit_instance_id
    ):
        return harness.fail_result("mid-turn action_legality lock should cancel queued enemy action before start")
    if _has_event(core.service("battle_logger").event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_CAST \
            and ev.actor_id == queue_lock_p2.unit_instance_id
    ):
        return harness.fail_result("locked queued action must not reach ACTION_CAST")
    return harness.pass_result()

func _test_action_legality_managed_action_matrix_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var matrix_cases := [
        {
            "seed": 920,
            "value": "skill",
            "action_type": CommandTypesScript.SKILL,
            "skill_id": "sample_strike",
            "expected": false,
            "label": "deny skill should block regular skills",
        },
        {
            "seed": 921,
            "value": "skill",
            "action_type": CommandTypesScript.ULTIMATE,
            "skill_id": "sample_ultimate_burst",
            "expected": true,
            "label": "deny skill should not block ultimates",
        },
        {
            "seed": 922,
            "value": "ultimate",
            "action_type": CommandTypesScript.ULTIMATE,
            "skill_id": "sample_ultimate_burst",
            "expected": false,
            "label": "deny ultimate should block ultimates",
        },
        {
            "seed": 923,
            "value": "ultimate",
            "action_type": CommandTypesScript.SKILL,
            "skill_id": "sample_strike",
            "expected": true,
            "label": "deny ultimate should not block regular skills",
        },
        {
            "seed": 924,
            "value": "switch",
            "action_type": CommandTypesScript.SWITCH,
            "skill_id": "",
            "expected": false,
            "label": "deny switch should block switches",
        },
        {
            "seed": 925,
            "value": "sample_strike",
            "action_type": CommandTypesScript.SKILL,
            "skill_id": "sample_strike",
            "expected": false,
            "label": "deny specific skill should block matching skill only",
        },
        {
            "seed": 926,
            "value": "sample_strike",
            "action_type": CommandTypesScript.SKILL,
            "skill_id": "sample_field_call",
            "expected": true,
            "label": "deny specific skill should not block other skills",
        },
    ]
    for matrix_case in matrix_cases:
        var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, int(matrix_case["seed"]))
        var actor = battle_state.get_side("P1").get_active_unit()
        var deny_payload = RuleModPayloadScript.new()
        deny_payload.payload_type = "rule_mod"
        deny_payload.mod_kind = "action_legality"
        deny_payload.mod_op = "deny"
        deny_payload.value = str(matrix_case["value"])
        deny_payload.scope = "self"
        deny_payload.duration_mode = "turns"
        deny_payload.duration = 2
        deny_payload.decrement_on = "turn_start"
        deny_payload.stacking = "replace"
        if core.service("rule_mod_service").create_instance(deny_payload, {"scope": "unit", "id": actor.unit_instance_id}, battle_state, "test_action_legality_matrix_%s" % str(matrix_case["seed"]), 0, actor.base_speed) == null:
            return harness.fail_result("failed to create matrix action_legality rule_mod")
        var actual_allowed: bool = core.service("rule_mod_service").is_action_allowed(
            battle_state,
            actor.unit_instance_id,
            str(matrix_case["action_type"]),
            str(matrix_case["skill_id"])
        )
        if actual_allowed != bool(matrix_case["expected"]):
            return harness.fail_result(str(matrix_case["label"]))
    return harness.pass_result()

func _test_action_legality_unknown_action_type_reports_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 927)
    var actor = battle_state.get_side("P1").get_active_unit()
    var is_allowed: bool = core.service("rule_mod_service").is_action_allowed(
        battle_state,
        actor.unit_instance_id,
        "test_unknown_action_type"
    )
    if is_allowed:
        return harness.fail_result("unknown managed action type must not silently pass legality check")
    var error_state: Dictionary = core.service("rule_mod_service").error_state()
    if error_state.get("code", null) != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return harness.fail_result("unknown managed action type should report invalid_command_payload")
    if String(error_state.get("message", "")).find("unsupported action_legality action_type") == -1:
        return harness.fail_result("unknown managed action type should expose explicit action_legality error message")
    return harness.pass_result()


func _has_event(event_log: Array, predicate: Callable) -> bool:
    for log_event in event_log:
        if predicate.call(log_event):
            return true
    return false
