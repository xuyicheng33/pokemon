extends RefCounted
class_name ExtensionValidationContractSuite

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("extension_validation_contract", failures, Callable(self, "_test_extension_validation_contract").bind(harness))
    runner.run_test("formal_gojo_validator_bad_case_contract", failures, Callable(self, "_test_formal_gojo_validator_bad_case_contract").bind(harness))
    runner.run_test("formal_sukuna_validator_bad_case_contract", failures, Callable(self, "_test_formal_sukuna_validator_bad_case_contract").bind(harness))
    runner.run_test("formal_kashimo_validator_bad_case_contract", failures, Callable(self, "_test_formal_kashimo_validator_bad_case_contract").bind(harness))
    runner.run_test("formal_kashimo_validator_kyokyo_bad_case_contract", failures, Callable(self, "_test_formal_kashimo_validator_kyokyo_bad_case_contract").bind(harness))

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

    var bad_nullify_payload = RuleModPayloadScript.new()
    bad_nullify_payload.payload_type = "rule_mod"
    bad_nullify_payload.mod_kind = "nullify_field_accuracy"
    bad_nullify_payload.mod_op = "add"
    bad_nullify_payload.value = 1
    bad_nullify_payload.scope = "self"
    bad_nullify_payload.duration_mode = "permanent"
    bad_nullify_payload.decrement_on = "turn_end"
    bad_nullify_payload.stacking = "none"
    var bad_nullify_effect = EffectDefinitionScript.new()
    bad_nullify_effect.id = "test_bad_nullify_field_accuracy"
    bad_nullify_effect.display_name = "Bad Nullify Field Accuracy"
    bad_nullify_effect.scope = "self"
    bad_nullify_effect.payloads.append(bad_nullify_payload)
    content_index.register_resource(bad_nullify_effect)

    var bad_incoming_final_payload = RuleModPayloadScript.new()
    bad_incoming_final_payload.payload_type = "rule_mod"
    bad_incoming_final_payload.mod_kind = "incoming_action_final_mod"
    bad_incoming_final_payload.mod_op = "mul"
    bad_incoming_final_payload.value = "bad"
    bad_incoming_final_payload.scope = "self"
    bad_incoming_final_payload.duration_mode = "turns"
    bad_incoming_final_payload.duration = 1
    bad_incoming_final_payload.decrement_on = "turn_start"
    bad_incoming_final_payload.stacking = "replace"
    bad_incoming_final_payload.required_incoming_command_types = PackedStringArray(["wait"])
    bad_incoming_final_payload.required_incoming_combat_type_ids = PackedStringArray(["missing_combat_type"])
    var bad_incoming_final_effect = EffectDefinitionScript.new()
    bad_incoming_final_effect.id = "test_bad_incoming_action_final_mod"
    bad_incoming_final_effect.display_name = "Bad Incoming Action Final Mod"
    bad_incoming_final_effect.scope = "self"
    bad_incoming_final_effect.payloads.append(bad_incoming_final_payload)
    content_index.register_resource(bad_incoming_final_effect)

    var bad_persistent_field_payload = RuleModPayloadScript.new()
    bad_persistent_field_payload.payload_type = "rule_mod"
    bad_persistent_field_payload.mod_kind = "mp_regen"
    bad_persistent_field_payload.mod_op = "add"
    bad_persistent_field_payload.value = 3
    bad_persistent_field_payload.scope = "field"
    bad_persistent_field_payload.duration_mode = "turns"
    bad_persistent_field_payload.duration = 1
    bad_persistent_field_payload.decrement_on = "turn_start"
    bad_persistent_field_payload.stacking = "replace"
    bad_persistent_field_payload.persists_on_switch = true
    var bad_persistent_field_effect = EffectDefinitionScript.new()
    bad_persistent_field_effect.id = "test_bad_persistent_field_rule_mod"
    bad_persistent_field_effect.display_name = "Bad Persistent Field Rule Mod"
    bad_persistent_field_effect.scope = "field"
    bad_persistent_field_effect.payloads.append(bad_persistent_field_payload)
    content_index.register_resource(bad_persistent_field_effect)

    var bad_persistent_nested_payload = RuleModPayloadScript.new()
    bad_persistent_nested_payload.payload_type = "rule_mod"
    bad_persistent_nested_payload.mod_kind = "mp_regen"
    bad_persistent_nested_payload.mod_op = "add"
    bad_persistent_nested_payload.value = 2
    bad_persistent_nested_payload.scope = "self"
    bad_persistent_nested_payload.duration_mode = "turns"
    bad_persistent_nested_payload.duration = 1
    bad_persistent_nested_payload.decrement_on = "turn_start"
    bad_persistent_nested_payload.stacking = "replace"
    var bad_persistent_nested_effect = EffectDefinitionScript.new()
    bad_persistent_nested_effect.id = "test_bad_persistent_nested_rule_mod"
    bad_persistent_nested_effect.display_name = "Bad Persistent Nested Rule Mod"
    bad_persistent_nested_effect.scope = "self"
    bad_persistent_nested_effect.persists_on_switch = true
    bad_persistent_nested_effect.payloads.append(bad_persistent_nested_payload)
    content_index.register_resource(bad_persistent_nested_effect)

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

    var bad_required_same_owner_scope = EffectDefinitionScript.new()
    bad_required_same_owner_scope.id = "test_bad_required_same_owner_scope"
    bad_required_same_owner_scope.display_name = "Bad Required Same Owner Scope"
    bad_required_same_owner_scope.scope = "self"
    bad_required_same_owner_scope.required_target_effects = PackedStringArray([marker_effect.id])
    bad_required_same_owner_scope.required_target_same_owner = true
    content_index.register_resource(bad_required_same_owner_scope)

    var bad_required_same_owner_missing = EffectDefinitionScript.new()
    bad_required_same_owner_missing.id = "test_bad_required_same_owner_missing"
    bad_required_same_owner_missing.display_name = "Bad Required Same Owner Missing"
    bad_required_same_owner_missing.scope = "target"
    bad_required_same_owner_missing.required_target_same_owner = true
    content_index.register_resource(bad_required_same_owner_missing)

    var errors: Array = content_index.validate_snapshot()
    var needles := [
        "effect[test_bad_action_legality].rule_mod invalid: action_legality value missing skill: missing_skill_id",
        "effect[test_bad_incoming_accuracy].rule_mod invalid: incoming_accuracy value must be int",
        "effect[test_bad_nullify_field_accuracy].rule_mod invalid: mod_op add",
        "effect[test_bad_nullify_field_accuracy].rule_mod invalid: nullify_field_accuracy value must be bool",
        "effect[test_bad_incoming_action_final_mod].rule_mod invalid: incoming_action_final_mod value must be number",
        "effect[test_bad_incoming_action_final_mod].rule_mod invalid: required_incoming_command_types invalid: wait",
        "effect[test_bad_incoming_action_final_mod].rule_mod invalid: required_incoming_combat_type_ids missing combat type: missing_combat_type",
        "effect[test_bad_persistent_field_rule_mod].rule_mod invalid: persists_on_switch is not allowed for field scope",
        "effect[test_bad_persistent_nested_rule_mod].rule_mod persists_on_switch must be true when effect persists_on_switch=true",
        "effect[test_bad_required_scope].required_target_effects requires scope=target",
        "effect[test_bad_required_missing].required_target_effects missing effect: missing_required_effect",
        "effect[test_bad_required_duplicate].required_target_effects duplicated effect: test_required_marker",
        "effect[test_bad_required_same_owner_scope].required_target_effects requires scope=target",
        "effect[test_bad_required_same_owner_scope].required_target_same_owner requires scope=target",
        "effect[test_bad_required_same_owner_missing].required_target_same_owner requires required_target_effects",
    ]
    for needle in needles:
        if not _has_error(errors, needle):
            return harness.fail_result("extension validation missing error: %s" % needle)
    return harness.pass_result()

func _test_formal_gojo_validator_bad_case_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var gojo_ao = content_index.skills.get("gojo_ao", null)
    if gojo_ao == null:
        return harness.fail_result("missing gojo_ao")
    gojo_ao.power = 45
    var errors: Array = content_index.validate_snapshot()
    if not _has_error(errors, "formal[gojo].ao power mismatch: expected 44 got 45"):
        return harness.fail_result("gojo formal validator should fail-fast when ao power drifts")
    return harness.pass_result()

func _test_formal_sukuna_validator_bad_case_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var sukuna_kai = content_index.skills.get("sukuna_kai", null)
    if sukuna_kai == null:
        return harness.fail_result("missing sukuna_kai")
    sukuna_kai.priority = 0
    var errors: Array = content_index.validate_snapshot()
    if not _has_error(errors, "formal[sukuna].kai priority mismatch: expected 1 got 0"):
        return harness.fail_result("sukuna formal validator should fail-fast when kai priority drifts")
    return harness.pass_result()

func _test_formal_kashimo_validator_bad_case_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var kashimo_charge = content_index.skills.get("kashimo_charge", null)
    if kashimo_charge == null:
        return harness.fail_result("missing kashimo_charge")
    kashimo_charge.mp_cost = 9
    var errors: Array = content_index.validate_snapshot()
    if not _has_error(errors, "formal[kashimo].charge mp_cost mismatch: expected 8 got 9"):
        return harness.fail_result("kashimo formal validator should fail-fast when charge mp_cost drifts")
    return harness.pass_result()

func _test_formal_kashimo_validator_kyokyo_bad_case_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var kyokyo = content_index.skills.get("kashimo_kyokyo_katsura", null)
    if kyokyo == null:
        return harness.fail_result("missing kashimo_kyokyo_katsura")
    kyokyo.priority = 1
    var errors: Array = content_index.validate_snapshot()
    if not _has_error(errors, "formal[kashimo].kyokyo priority mismatch: expected 2 got 1"):
        return harness.fail_result("kashimo formal validator should fail-fast when kyokyo priority drifts")
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
