extends RefCounted
class_name ExtensionContractSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("extension_validation_contract", failures, Callable(self, "_test_extension_validation_contract").bind(harness))
    runner.run_test("action_legality_contract", failures, Callable(self, "_test_action_legality_contract").bind(harness))
    runner.run_test("required_target_effects_contract", failures, Callable(self, "_test_required_target_effects_contract").bind(harness))
    runner.run_test("incoming_accuracy_contract", failures, Callable(self, "_test_incoming_accuracy_contract").bind(harness))

func _test_extension_validation_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var marker_effect = EffectDefinitionScript.new()
    marker_effect.id = "test_required_marker"
    marker_effect.display_name = "Required Marker"
    marker_effect.scope = "self"
    content_index.register_resource(marker_effect)

    var bad_action_payload = RuleModPayloadScript.new()
    bad_action_payload.payload_type = "rule_mod"
    bad_action_payload.mod_kind = "action_legality"
    bad_action_payload.mod_op = "deny"
    bad_action_payload.value = "missing_skill_id"
    bad_action_payload.scope = "self"
    bad_action_payload.duration_mode = "turns"
    bad_action_payload.duration = 1
    bad_action_payload.decrement_on = "turn_start"
    bad_action_payload.stacking = "replace"
    var bad_action_effect = EffectDefinitionScript.new()
    bad_action_effect.id = "test_bad_action_legality"
    bad_action_effect.display_name = "Bad Action Legality"
    bad_action_effect.scope = "self"
    bad_action_effect.payloads.append(bad_action_payload)
    content_index.register_resource(bad_action_effect)

    var bad_accuracy_payload = RuleModPayloadScript.new()
    bad_accuracy_payload.payload_type = "rule_mod"
    bad_accuracy_payload.mod_kind = "incoming_accuracy"
    bad_accuracy_payload.mod_op = "add"
    bad_accuracy_payload.value = 1.5
    bad_accuracy_payload.scope = "self"
    bad_accuracy_payload.duration_mode = "permanent"
    bad_accuracy_payload.decrement_on = "turn_end"
    bad_accuracy_payload.stacking = "none"
    var bad_accuracy_effect = EffectDefinitionScript.new()
    bad_accuracy_effect.id = "test_bad_incoming_accuracy"
    bad_accuracy_effect.display_name = "Bad Incoming Accuracy"
    bad_accuracy_effect.scope = "self"
    bad_accuracy_effect.payloads.append(bad_accuracy_payload)
    content_index.register_resource(bad_accuracy_effect)

    var bad_required_scope = EffectDefinitionScript.new()
    bad_required_scope.id = "test_bad_required_scope"
    bad_required_scope.display_name = "Bad Required Scope"
    bad_required_scope.scope = "self"
    bad_required_scope.required_target_effects = PackedStringArray([marker_effect.id])
    content_index.register_resource(bad_required_scope)

    var bad_required_missing = EffectDefinitionScript.new()
    bad_required_missing.id = "test_bad_required_missing"
    bad_required_missing.display_name = "Bad Required Missing"
    bad_required_missing.scope = "target"
    bad_required_missing.required_target_effects = PackedStringArray(["missing_required_effect"])
    content_index.register_resource(bad_required_missing)

    var bad_required_duplicate = EffectDefinitionScript.new()
    bad_required_duplicate.id = "test_bad_required_duplicate"
    bad_required_duplicate.display_name = "Bad Required Duplicate"
    bad_required_duplicate.scope = "target"
    bad_required_duplicate.required_target_effects = PackedStringArray([marker_effect.id, marker_effect.id])
    content_index.register_resource(bad_required_duplicate)

    var errors: Array = content_index.validate_snapshot()
    var needles := [
        "effect[test_bad_action_legality].rule_mod invalid: action_legality value missing skill: missing_skill_id",
        "effect[test_bad_incoming_accuracy].rule_mod invalid: incoming_accuracy value must be int",
        "effect[test_bad_required_scope].required_target_effects requires scope=target",
        "effect[test_bad_required_missing].required_target_effects missing effect: missing_required_effect",
        "effect[test_bad_required_duplicate].required_target_effects duplicated effect: test_required_marker",
    ]
    for needle in needles:
        if not _has_error(errors, needle):
            return harness.fail_result("extension validation missing error: %s" % needle)
    return harness.pass_result()

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
    if core.rule_mod_service.create_instance(deny_all, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_action_legality_deny_all", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create action_legality deny all instance")
    var denied_actions = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if denied_actions.wait_allowed != true or denied_actions.forced_command_type != "":
        return harness.fail_result("deny all should leave wait legal and must not fall back to resource_forced_default")
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
    if core.rule_mod_service.create_instance(allow_switch, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_action_legality_allow_switch", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create action_legality allow switch instance")
    var allow_switch_actions = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
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
    if core.rule_mod_service.create_instance(deny_skill, {"scope": "unit", "id": selective_actor.unit_instance_id}, selective_state, "test_action_legality_deny_skill", 0, selective_actor.base_speed) == null:
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
    if core.rule_mod_service.create_instance(allow_specific, {"scope": "unit", "id": selective_actor.unit_instance_id}, selective_state, "test_action_legality_allow_specific", 0, selective_actor.base_speed) == null:
        return harness.fail_result("failed to create action_legality allow specific instance")
    var selective_actions = core.legal_action_service.get_legal_actions(selective_state, "P1", content_index)
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(queue_lock_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": lock_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    if not _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START \
            and ev.target_instance_id == queue_lock_p2.unit_instance_id
    ):
        return harness.fail_result("mid-turn action_legality lock should cancel queued enemy action before start")
    if _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_CAST \
            and ev.actor_id == queue_lock_p2.unit_instance_id
    ):
        return harness.fail_result("locked queued action must not reach ACTION_CAST")
    return harness.pass_result()

func _test_required_target_effects_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var marker_effect = EffectDefinitionScript.new()
    marker_effect.id = "test_required_runtime_marker"
    marker_effect.display_name = "Required Runtime Marker"
    marker_effect.scope = "self"
    marker_effect.duration_mode = "turns"
    marker_effect.duration = 2
    marker_effect.decrement_on = "turn_end"
    marker_effect.stacking = "replace"
    content_index.register_resource(marker_effect)

    var stat_payload = StatModPayloadScript.new()
    stat_payload.payload_type = "stat_mod"
    stat_payload.stat_name = "speed"
    stat_payload.stage_delta = -1
    var conditional_effect = EffectDefinitionScript.new()
    conditional_effect.id = "test_required_conditional_effect"
    conditional_effect.display_name = "Required Conditional Effect"
    conditional_effect.scope = "target"
    conditional_effect.trigger_names = PackedStringArray(["on_hit"])
    conditional_effect.required_target_effects = PackedStringArray([marker_effect.id])
    conditional_effect.payloads.append(stat_payload)
    content_index.register_resource(conditional_effect)

    var conditional_skill = SkillDefinitionScript.new()
    conditional_skill.id = "test_required_conditional_skill"
    conditional_skill.display_name = "Required Conditional Skill"
    conditional_skill.damage_kind = "none"
    conditional_skill.power = 0
    conditional_skill.accuracy = 100
    conditional_skill.mp_cost = 0
    conditional_skill.priority = 0
    conditional_skill.targeting = "enemy_active_slot"
    conditional_skill.effects_on_hit_ids = PackedStringArray([conditional_effect.id])
    content_index.register_resource(conditional_skill)

    var skipped_state = harness.build_initialized_battle(core, content_index, sample_factory, 907)
    var skipped_p1 = skipped_state.get_side("P1").get_active_unit()
    var skipped_p2 = skipped_state.get_side("P2").get_active_unit()
    skipped_p1.regular_skill_ids[0] = conditional_skill.id
    skipped_p1.base_speed = 999
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(skipped_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": conditional_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if int(skipped_p2.stat_stages.get("speed", 0)) != 0:
        return harness.fail_result("required_target_effects should skip payloads when target marker is missing")
    if _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.EFFECT_STAT_MOD \
            and ev.target_instance_id == skipped_p2.unit_instance_id
    ):
        return harness.fail_result("required_target_effects skip path must not emit payload logs")

    var applied_state = harness.build_initialized_battle(core, content_index, sample_factory, 908)
    var applied_p1 = applied_state.get_side("P1").get_active_unit()
    var applied_p2 = applied_state.get_side("P2").get_active_unit()
    applied_p1.regular_skill_ids[0] = conditional_skill.id
    applied_p1.base_speed = 999
    core.effect_instance_service.create_instance(marker_effect, applied_p2.unit_instance_id, applied_state, "test_required_runtime_marker_source", 0, applied_p2.base_speed)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(applied_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": conditional_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if int(applied_p2.stat_stages.get("speed", 0)) != -1:
        return harness.fail_result("required_target_effects should allow payloads once target marker exists")
    return harness.pass_result()

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
    if core.rule_mod_service.create_instance(incoming_payload, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "test_incoming_accuracy_down", 0, p2_active.base_speed) == null:
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

    var command = core.command_builder.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_public_id": "P1-A",
        "skill_id": accuracy_skill.id,
    })
    command.actor_id = p1_active.unit_instance_id
    var hit_info = core.action_cast_service.resolve_hit(command, accuracy_skill, p2_active, battle_state, content_index)
    if abs(float(hit_info.get("hit_rate", -1.0)) - 0.85) > 0.0001:
        return harness.fail_result("incoming_accuracy should reduce 95 accuracy enemy_active skill to 85")

    accuracy_skill.accuracy = 100
    var guaranteed_hit_info = core.action_cast_service.resolve_hit(command, accuracy_skill, p2_active, battle_state, content_index)
    if guaranteed_hit_info.get("hit_roll", "not-null") != null or abs(float(guaranteed_hit_info.get("hit_rate", -1.0)) - 1.0) > 0.0001:
        return harness.fail_result("incoming_accuracy must not affect guaranteed-hit actions")

    accuracy_skill.accuracy = 95
    accuracy_skill.targeting = "self"
    var self_target_hit_info = core.action_cast_service.resolve_hit(command, accuracy_skill, p1_active, battle_state, content_index)
    if abs(float(self_target_hit_info.get("hit_rate", -1.0)) - 0.95) > 0.0001:
        return harness.fail_result("incoming_accuracy must not affect self-target actions")
    return harness.pass_result()

func _has_error(errors: Array, needle: String) -> bool:
    for error_msg in errors:
        if String(error_msg).find(needle) != -1:
            return true
    return false

func _has_event(event_log: Array, predicate: Callable) -> bool:
    for log_event in event_log:
        if predicate.call(log_event):
            return true
    return false
