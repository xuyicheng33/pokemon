extends "res://test/suites/extension_validation_contract/base.gd"

func test_extension_validation_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)

	var marker_effect = EffectDefinitionScript.new()
	marker_effect.id = "test_required_marker"
	marker_effect.display_name = "Required Marker"
	marker_effect.scope = "self"
	content_index.register_resource(marker_effect)
	var stacked_marker_effect = EffectDefinitionScript.new()
	stacked_marker_effect.id = "test_stacked_marker"
	stacked_marker_effect.display_name = "Stacked Marker"
	stacked_marker_effect.scope = "self"
	stacked_marker_effect.stacking = "stack"
	content_index.register_resource(stacked_marker_effect)

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
	bad_action_payload.priority = 11
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

	var bad_action_actor_payload = DamagePayloadScript.new()
	bad_action_actor_payload.payload_type = "damage"
	bad_action_actor_payload.amount = 10
	bad_action_actor_payload.use_formula = false
	var bad_action_actor_effect = EffectDefinitionScript.new()
	bad_action_actor_effect.id = "test_bad_action_actor_trigger"
	bad_action_actor_effect.display_name = "Bad Action Actor Trigger"
	bad_action_actor_effect.scope = "action_actor"
	bad_action_actor_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_action_actor_effect.payloads.append(bad_action_actor_payload)
	content_index.register_resource(bad_action_actor_effect)

	var bad_field_damage_payload = DamagePayloadScript.new()
	bad_field_damage_payload.payload_type = "damage"
	bad_field_damage_payload.amount = 10
	bad_field_damage_payload.use_formula = false
	var bad_field_damage_effect = EffectDefinitionScript.new()
	bad_field_damage_effect.id = "test_bad_field_damage"
	bad_field_damage_effect.display_name = "Bad Field Damage"
	bad_field_damage_effect.scope = "field"
	bad_field_damage_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_field_damage_effect.payloads.append(bad_field_damage_payload)
	content_index.register_resource(bad_field_damage_effect)

	var bad_field_heal_payload = HealPayloadScript.new()
	bad_field_heal_payload.payload_type = "heal"
	bad_field_heal_payload.amount = 10
	var bad_field_heal_effect = EffectDefinitionScript.new()
	bad_field_heal_effect.id = "test_bad_field_heal"
	bad_field_heal_effect.display_name = "Bad Field Heal"
	bad_field_heal_effect.scope = "field"
	bad_field_heal_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_field_heal_effect.payloads.append(bad_field_heal_payload)
	content_index.register_resource(bad_field_heal_effect)

	var bad_field_resource_payload = ResourceModPayloadScript.new()
	bad_field_resource_payload.payload_type = "resource_mod"
	bad_field_resource_payload.resource_key = "mp"
	bad_field_resource_payload.amount = 3
	var bad_field_resource_effect = EffectDefinitionScript.new()
	bad_field_resource_effect.id = "test_bad_field_resource_mod"
	bad_field_resource_effect.display_name = "Bad Field Resource"
	bad_field_resource_effect.scope = "field"
	bad_field_resource_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_field_resource_effect.payloads.append(bad_field_resource_payload)
	content_index.register_resource(bad_field_resource_effect)

	var bad_field_stat_payload = StatModPayloadScript.new()
	bad_field_stat_payload.payload_type = "stat_mod"
	bad_field_stat_payload.stat_name = "speed"
	bad_field_stat_payload.stage_delta = 1
	bad_field_stat_payload.retention_mode = "normal"
	var bad_field_stat_effect = EffectDefinitionScript.new()
	bad_field_stat_effect.id = "test_bad_field_stat_mod"
	bad_field_stat_effect.display_name = "Bad Field Stat Mod"
	bad_field_stat_effect.scope = "field"
	bad_field_stat_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_field_stat_effect.payloads.append(bad_field_stat_payload)
	content_index.register_resource(bad_field_stat_effect)

	var bad_stage_delta_payload = StatModPayloadScript.new()
	bad_stage_delta_payload.payload_type = "stat_mod"
	bad_stage_delta_payload.stat_name = "speed"
	bad_stage_delta_payload.stage_delta = 3
	bad_stage_delta_payload.retention_mode = "normal"
	var bad_stage_delta_effect = EffectDefinitionScript.new()
	bad_stage_delta_effect.id = "test_bad_stage_delta"
	bad_stage_delta_effect.display_name = "Bad Stage Delta"
	bad_stage_delta_effect.scope = "self"
	bad_stage_delta_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_stage_delta_effect.payloads.append(bad_stage_delta_payload)
	content_index.register_resource(bad_stage_delta_effect)

	var bad_field_apply_effect_payload = ApplyEffectPayloadScript.new()
	bad_field_apply_effect_payload.payload_type = "apply_effect"
	bad_field_apply_effect_payload.effect_definition_id = marker_effect.id
	var bad_field_apply_effect_effect = EffectDefinitionScript.new()
	bad_field_apply_effect_effect.id = "test_bad_field_apply_effect"
	bad_field_apply_effect_effect.display_name = "Bad Field Apply Effect"
	bad_field_apply_effect_effect.scope = "field"
	bad_field_apply_effect_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_field_apply_effect_effect.payloads.append(bad_field_apply_effect_payload)
	content_index.register_resource(bad_field_apply_effect_effect)

	var bad_field_remove_effect_payload = RemoveEffectPayloadScript.new()
	bad_field_remove_effect_payload.payload_type = "remove_effect"
	bad_field_remove_effect_payload.effect_definition_id = marker_effect.id
	bad_field_remove_effect_payload.remove_mode = "single"
	var bad_field_remove_effect = EffectDefinitionScript.new()
	bad_field_remove_effect.id = "test_bad_field_remove_effect"
	bad_field_remove_effect.display_name = "Bad Field Remove Effect"
	bad_field_remove_effect.scope = "field"
	bad_field_remove_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_field_remove_effect.payloads.append(bad_field_remove_effect_payload)
	content_index.register_resource(bad_field_remove_effect)

	var bad_stack_single_remove_payload = RemoveEffectPayloadScript.new()
	bad_stack_single_remove_payload.payload_type = "remove_effect"
	bad_stack_single_remove_payload.effect_definition_id = stacked_marker_effect.id
	bad_stack_single_remove_payload.remove_mode = "single"
	var bad_stack_single_remove_effect = EffectDefinitionScript.new()
	bad_stack_single_remove_effect.id = "test_bad_stack_single_remove"
	bad_stack_single_remove_effect.display_name = "Bad Stack Single Remove"
	bad_stack_single_remove_effect.scope = "self"
	bad_stack_single_remove_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_stack_single_remove_effect.payloads.append(bad_stack_single_remove_payload)
	content_index.register_resource(bad_stack_single_remove_effect)

	var bad_non_field_apply_field_payload = ApplyFieldPayloadScript.new()
	bad_non_field_apply_field_payload.payload_type = "apply_field"
	bad_non_field_apply_field_payload.field_definition_id = "sample_focus_field"
	var bad_non_field_apply_field_effect = EffectDefinitionScript.new()
	bad_non_field_apply_field_effect.id = "test_bad_non_field_apply_field"
	bad_non_field_apply_field_effect.display_name = "Bad Non Field Apply Field"
	bad_non_field_apply_field_effect.scope = "self"
	bad_non_field_apply_field_effect.trigger_names = PackedStringArray(["on_hit"])
	bad_non_field_apply_field_effect.payloads.append(bad_non_field_apply_field_payload)
	content_index.register_resource(bad_non_field_apply_field_effect)

	var errors: Array = content_index.validate_snapshot()
	var needles := [
		"effect[test_bad_action_legality].rule_mod invalid: action_legality value missing skill: missing_skill_id",
		"effect[test_bad_action_legality].rule_mod invalid: priority 11",
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
		"effect[test_bad_action_actor_trigger].scope action_actor only allowed for on_receive_action_hit",
		"effect[test_bad_field_damage].damage requires scope=self/target/action_actor",
		"effect[test_bad_field_heal].heal requires scope=self/target/action_actor",
		"effect[test_bad_field_resource_mod].resource_mod requires scope=self/target/action_actor",
		"effect[test_bad_field_stat_mod].stat_mod requires scope=self/target/action_actor",
		"effect[test_bad_stage_delta].stat_mod stage_delta out of range: 3",
		"effect[test_bad_field_apply_effect].apply_effect requires scope=self/target/action_actor",
		"effect[test_bad_field_remove_effect].remove_effect requires scope=self/target/action_actor",
		"effect[test_bad_stack_single_remove].remove_effect single cannot target stacking effect: test_stacked_marker",
		"effect[test_bad_non_field_apply_field].apply_field requires scope=field",
		"effect[test_bad_non_field_apply_field].apply_field carrier duration_mode must be turns",
		"effect[test_bad_non_field_apply_field].apply_field carrier duration must be > 0",
	]
	for needle in needles:
		if not _has_error(errors, needle):
			fail("extension validation missing error: %s" % needle)
			return
