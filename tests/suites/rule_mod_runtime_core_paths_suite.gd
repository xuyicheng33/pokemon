extends RefCounted
class_name RuleModRuntimeCorePathsSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("rule_mod_paths", failures, Callable(self, "_test_rule_mod_paths").bind(harness))
    runner.run_test("rule_mod_field_scope_paths", failures, Callable(self, "_test_rule_mod_field_scope_paths").bind(harness))
    runner.run_test("rule_mod_multi_source_grouping_paths", failures, Callable(self, "_test_rule_mod_multi_source_grouping_paths").bind(harness))

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
    deny_payload.mod_kind = "action_legality"
    deny_payload.mod_op = "deny"
    deny_payload.value = "sample_strike"
    deny_payload.scope = "self"
    deny_payload.duration_mode = "turns"
    deny_payload.duration = 2
    deny_payload.decrement_on = "turn_start"
    deny_payload.stacking = "replace"
    deny_payload.priority = 10
    if core.service("rule_mod_service").create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_deny", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create action_legality rule_mod")

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
    if core.service("rule_mod_service").create_instance(regen_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_regen", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create mp_regen rule_mod")

    var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
    if legal_action_set.legal_skill_ids.has("sample_strike"):
        return harness.fail_result("action_legality rule_mod did not block sample_strike")

    core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
    if p1_active.current_mp != p1_before_mp:
        return harness.fail_result("mp_regen rule_mod did not override turn_start regen")
    var has_remove_log := false
    for ev in core.service("battle_logger").event_log:
        if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == p1_active.unit_instance_id:
            has_remove_log = true
            break
    if not has_remove_log:
        return harness.fail_result("rule_mod remove event missing")

    var baseline_state = harness.build_initialized_battle(core, content_index, sample_factory, 105)
    var modded_state = harness.build_initialized_battle(core, content_index, sample_factory, 105)
    var baseline_commands: Array = [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(baseline_state, content_index, baseline_commands)
    var baseline_damage = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")

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
    if core.service("rule_mod_service").create_instance(final_mod_payload, {"scope": "unit", "id": modded_p1_active.unit_instance_id}, modded_state, "test_rule_mod_final", 0, modded_p1_active.base_speed) == null:
        return harness.fail_result("failed to create final_mod rule_mod")
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(modded_state, content_index, baseline_commands)
    var modded_damage = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
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
    field_regen_payload.duration = 2
    field_regen_payload.decrement_on = "turn_start"
    field_regen_payload.stacking = "replace"
    field_regen_payload.priority = 5
    if core.service("rule_mod_service").create_instance(field_regen_payload, {"scope": "field", "id": "field"}, battle_state, "test_field_regen_mod", 0, 0) == null:
        return harness.fail_result("failed to create field-scope mp_regen rule_mod")
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
    if p1_active.current_mp != 5 or p2_active.current_mp != 5:
        return harness.fail_result("field-scope mp_regen rule_mod did not apply to both active units")
    var has_field_remove_log := false
    for ev in core.service("battle_logger").event_log:
        if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == "field":
            has_field_remove_log = true
            break
    if not has_field_remove_log:
        return harness.fail_result("field-scope rule_mod remove event missing")

    var baseline_state = harness.build_initialized_battle(core, content_index, sample_factory, 116)
    var modded_state = harness.build_initialized_battle(core, content_index, sample_factory, 116)
    var baseline_commands: Array = [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(baseline_state, content_index, baseline_commands)
    var baseline_damage = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
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
    if core.service("rule_mod_service").create_instance(field_final_mod_payload, {"scope": "field", "id": "field"}, modded_state, "test_field_final_mod", 0, 0) == null:
        return harness.fail_result("failed to create field-scope final_mod rule_mod")
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(modded_state, content_index, baseline_commands)
    var modded_damage = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
    if baseline_damage <= 0 or modded_damage <= baseline_damage:
        return harness.fail_result("field-scope final_mod rule_mod did not increase damage")

    var legality_state = harness.build_initialized_battle(core, content_index, sample_factory, 117)
    var field_legality_payload = RuleModPayloadScript.new()
    field_legality_payload.payload_type = "rule_mod"
    field_legality_payload.mod_kind = "action_legality"
    field_legality_payload.mod_op = "deny"
    field_legality_payload.value = "sample_strike"
    field_legality_payload.scope = "field"
    field_legality_payload.duration_mode = "turns"
    field_legality_payload.duration = 2
    field_legality_payload.decrement_on = "turn_start"
    field_legality_payload.stacking = "replace"
    field_legality_payload.priority = 10
    if core.service("rule_mod_service").create_instance(field_legality_payload, {"scope": "field", "id": "field"}, legality_state, "test_field_action_legality", 0, 0) == null:
        return harness.fail_result("failed to create field-scope action_legality rule_mod")
    var legal_action_set = core.service("legal_action_service").get_legal_actions(legality_state, "P1", content_index)
    if legal_action_set.legal_skill_ids.has("sample_strike"):
        return harness.fail_result("field-scope action_legality rule_mod did not block sample_strike")

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
    if core.service("rule_mod_service").create_instance(invalid_scope_payload, {"scope": "unit", "id": invalid_owner.unit_instance_id}, legality_state, "test_invalid_field_owner", 0, invalid_owner.base_speed) != null:
        return harness.fail_result("invalid field owner binding should fail")
    if core.service("rule_mod_service").last_error_code != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
        return harness.fail_result("invalid field owner binding should return invalid_rule_mod_definition")
    return harness.pass_result()

func _test_rule_mod_multi_source_grouping_paths(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 119)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    if p1_active == null or p2_active == null:
        return harness.fail_result("missing active units for multi-source rule_mod contract")
    var regen_payload_a = _build_numeric_rule_mod_payload("mp_regen", "add", 2, "regen:passive")
    if core.service("rule_mod_service").create_instance(regen_payload_a, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_a", 0, p1_active.base_speed, null, "effect_regen_a") == null:
        return harness.fail_result("failed to create first mp_regen grouped rule_mod")
    var regen_payload_b = _build_numeric_rule_mod_payload("mp_regen", "add", 3, "regen:item")
    if core.service("rule_mod_service").create_instance(regen_payload_b, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_b", 0, p1_active.base_speed, null, "effect_regen_b") == null:
        return harness.fail_result("failed to create second mp_regen grouped rule_mod")
    if _count_rule_mod_instances(p1_active, "mp_regen") != 2:
        return harness.fail_result("different mp_regen source groups should coexist at runtime")
    if core.service("rule_mod_service").resolve_mp_regen_value(battle_state, p1_active.unit_instance_id, 0) != 5:
        return harness.fail_result("different mp_regen source groups should add together")
    var regen_payload_replace = _build_numeric_rule_mod_payload("mp_regen", "add", 4, "regen:passive")
    if core.service("rule_mod_service").create_instance(regen_payload_replace, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_a_replace", 0, p1_active.base_speed, null, "effect_regen_c") == null:
        return harness.fail_result("failed to replace grouped mp_regen rule_mod")
    if _count_rule_mod_instances(p1_active, "mp_regen") != 2:
        return harness.fail_result("same mp_regen source group should replace instead of growing instance count")
    if core.service("rule_mod_service").resolve_mp_regen_value(battle_state, p1_active.unit_instance_id, 0) != 7:
        return harness.fail_result("same mp_regen source group should replace old value while other groups keep stacking")
    var regen_payload_none = _build_numeric_rule_mod_payload("mp_regen", "add", 99, "regen:passive")
    regen_payload_none.stacking = "none"
    if core.service("rule_mod_service").create_instance(regen_payload_none, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "regen_source_none", 0, p1_active.base_speed, null, "effect_regen_d") == null:
        return harness.fail_result("stacking=none grouped mp_regen should return existing instance instead of null")
    if _count_rule_mod_instances(p1_active, "mp_regen") != 2 or core.service("rule_mod_service").resolve_mp_regen_value(battle_state, p1_active.unit_instance_id, 0) != 7:
        return harness.fail_result("stacking=none should not duplicate grouped mp_regen instances")
    if not _unit_rule_mods_have_source_keys(p1_active, "mp_regen", PackedStringArray(["regen:passive", "regen:item"])):
        return harness.fail_result("mp_regen grouped instances should expose source_stacking_key at runtime")
    var incoming_payload_a = _build_numeric_rule_mod_payload("incoming_accuracy", "add", -10, "accuracy:passive")
    if core.service("rule_mod_service").create_instance(incoming_payload_a, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "accuracy_source_a", 0, p2_active.base_speed, null, "effect_accuracy_a") == null:
        return harness.fail_result("failed to create first incoming_accuracy grouped rule_mod")
    var incoming_payload_b = _build_numeric_rule_mod_payload("incoming_accuracy", "add", -5, "accuracy:field")
    if core.service("rule_mod_service").create_instance(incoming_payload_b, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "accuracy_source_b", 0, p2_active.base_speed, null, "effect_accuracy_b") == null:
        return harness.fail_result("failed to create second incoming_accuracy grouped rule_mod")
    if _count_rule_mod_instances(p2_active, "incoming_accuracy") != 2:
        return harness.fail_result("different incoming_accuracy source groups should coexist at runtime")
    if core.service("rule_mod_service").resolve_incoming_accuracy(battle_state, p2_active.unit_instance_id, 95) != 80:
        return harness.fail_result("different incoming_accuracy source groups should add together")
    var incoming_payload_replace = _build_numeric_rule_mod_payload("incoming_accuracy", "add", -12, "accuracy:passive")
    if core.service("rule_mod_service").create_instance(incoming_payload_replace, {"scope": "unit", "id": p2_active.unit_instance_id}, battle_state, "accuracy_source_replace", 0, p2_active.base_speed, null, "effect_accuracy_c") == null:
        return harness.fail_result("failed to replace grouped incoming_accuracy rule_mod")
    if _count_rule_mod_instances(p2_active, "incoming_accuracy") != 2:
        return harness.fail_result("same incoming_accuracy source group should replace instead of growing instance count")
    if core.service("rule_mod_service").resolve_incoming_accuracy(battle_state, p2_active.unit_instance_id, 95) != 78:
        return harness.fail_result("same incoming_accuracy source group should replace old value while other groups keep stacking")
    return harness.pass_result()

func _build_numeric_rule_mod_payload(mod_kind: String, mod_op: String, value, source_group: String):
    var payload = RuleModPayloadScript.new()
    payload.payload_type = "rule_mod"
    payload.mod_kind = mod_kind
    payload.mod_op = mod_op
    payload.value = value
    payload.scope = "self"
    payload.duration_mode = "turns"
    payload.duration = 2
    payload.decrement_on = "turn_start"
    payload.stacking = "replace"
    payload.priority = 5
    payload.stacking_source_key = source_group
    return payload

func _count_rule_mod_instances(unit_state, mod_kind: String) -> int:
    var count := 0
    for rule_mod_instance in unit_state.rule_mod_instances:
        if String(rule_mod_instance.mod_kind) == mod_kind:
            count += 1
    return count

func _unit_rule_mods_have_source_keys(unit_state, mod_kind: String, expected_keys: PackedStringArray) -> bool:
    var actual_keys: Array[String] = []
    for rule_mod_instance in unit_state.rule_mod_instances:
        if String(rule_mod_instance.mod_kind) != mod_kind:
            continue
        actual_keys.append(String(rule_mod_instance.source_stacking_key))
    actual_keys.sort()
    var sorted_expected: Array[String] = []
    for expected_key in expected_keys:
        sorted_expected.append(String(expected_key))
    sorted_expected.sort()
    return actual_keys == sorted_expected
