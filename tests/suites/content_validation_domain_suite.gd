extends RefCounted
class_name ContentValidationDomainSuite

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("nested_domain_skill_validation", failures, Callable(self, "_test_nested_domain_skill_validation").bind(harness))
	runner.run_test("domain_field_contract_validation", failures, Callable(self, "_test_domain_field_contract_validation").bind(harness))

func _test_nested_domain_skill_validation(harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var domain_field = FieldDefinitionScript.new()
	domain_field.id = "test_nested_domain_field"
	domain_field.display_name = "Nested Domain Field"
	domain_field.field_kind = ContentSchemaScript.FIELD_KIND_DOMAIN
	content_index.register_resource(domain_field)

	var nested_apply_field_payload = ApplyFieldPayloadScript.new()
	nested_apply_field_payload.payload_type = "apply_field"
	nested_apply_field_payload.field_definition_id = domain_field.id
	var nested_effect = EffectDefinitionScript.new()
	nested_effect.id = "test_nested_domain_effect"
	nested_effect.display_name = "Nested Domain Effect"
	nested_effect.scope = "field"
	nested_effect.duration_mode = ContentSchemaScript.DURATION_TURNS
	nested_effect.duration = 2
	nested_effect.decrement_on = "turn_end"
	nested_effect.trigger_names = PackedStringArray(["on_hit"])
	nested_effect.payloads.clear()
	nested_effect.payloads.append(nested_apply_field_payload)
	content_index.register_resource(nested_effect)

	var apply_effect_payload = ApplyEffectPayloadScript.new()
	apply_effect_payload.payload_type = "apply_effect"
	apply_effect_payload.effect_definition_id = nested_effect.id
	var skill_bridge_effect = EffectDefinitionScript.new()
	skill_bridge_effect.id = "test_nested_domain_bridge_effect"
	skill_bridge_effect.display_name = "Nested Domain Bridge"
	skill_bridge_effect.scope = "self"
	skill_bridge_effect.duration_mode = ContentSchemaScript.DURATION_PERMANENT
	skill_bridge_effect.trigger_names = PackedStringArray(["on_hit"])
	skill_bridge_effect.payloads.clear()
	skill_bridge_effect.payloads.append(apply_effect_payload)
	content_index.register_resource(skill_bridge_effect)

	var bad_skill = SkillDefinitionScript.new()
	bad_skill.id = "test_nested_domain_skill"
	bad_skill.display_name = "Nested Domain Skill"
	bad_skill.damage_kind = ContentSchemaScript.DAMAGE_KIND_NONE
	bad_skill.power = 0
	bad_skill.accuracy = 100
	bad_skill.mp_cost = 0
	bad_skill.priority = 5
	bad_skill.targeting = ContentSchemaScript.TARGET_FIELD
	bad_skill.effects_on_hit_ids = PackedStringArray([skill_bridge_effect.id])
	content_index.register_resource(bad_skill)

	var errors: Array = content_index.validate_snapshot()
	for error_msg in errors:
		if str(error_msg).find("skill[%s] applies domain field and must set is_domain_skill=true" % bad_skill.id) != -1:
			return harness.pass_result()
	return harness.fail_result("nested apply_effect -> apply_field(domain) should require is_domain_skill=true")

func _test_domain_field_contract_validation(harness) -> Dictionary:
	var content_index = BattleContentIndexScript.new()
	var missing_cleanup_domain = FieldDefinitionScript.new()
	missing_cleanup_domain.id = "test_domain_missing_cleanup"
	missing_cleanup_domain.display_name = "Missing Cleanup Domain"
	missing_cleanup_domain.field_kind = ContentSchemaScript.FIELD_KIND_DOMAIN
	content_index.register_resource(missing_cleanup_domain)

	var wrong_break_effect = EffectDefinitionScript.new()
	wrong_break_effect.id = "test_domain_wrong_break_effect"
	wrong_break_effect.display_name = "Wrong Break Trigger"
	wrong_break_effect.scope = "self"
	wrong_break_effect.trigger_names = PackedStringArray(["on_hit"])
	content_index.register_resource(wrong_break_effect)
	var wrong_expire_effect = EffectDefinitionScript.new()
	wrong_expire_effect.id = "test_domain_wrong_expire_effect"
	wrong_expire_effect.display_name = "Wrong Expire Trigger"
	wrong_expire_effect.scope = "self"
	wrong_expire_effect.trigger_names = PackedStringArray(["on_hit"])
	content_index.register_resource(wrong_expire_effect)
	var wrong_apply_effect = EffectDefinitionScript.new()
	wrong_apply_effect.id = "test_domain_wrong_apply_effect"
	wrong_apply_effect.display_name = "Wrong Apply Trigger"
	wrong_apply_effect.scope = "self"
	wrong_apply_effect.trigger_names = PackedStringArray(["on_hit"])
	content_index.register_resource(wrong_apply_effect)
	var trigger_mismatch_domain = FieldDefinitionScript.new()
	trigger_mismatch_domain.id = "test_domain_trigger_mismatch"
	trigger_mismatch_domain.display_name = "Trigger Mismatch Domain"
	trigger_mismatch_domain.field_kind = ContentSchemaScript.FIELD_KIND_DOMAIN
	trigger_mismatch_domain.effect_ids = PackedStringArray([wrong_apply_effect.id])
	trigger_mismatch_domain.on_break_effect_ids = PackedStringArray([wrong_break_effect.id])
	trigger_mismatch_domain.on_expire_effect_ids = PackedStringArray([wrong_expire_effect.id])
	content_index.register_resource(trigger_mismatch_domain)

	var errors: Array = content_index.validate_snapshot()
	if errors.is_empty():
		return harness.fail_result("domain field contract validation should fail-fast")
	var has_missing_effect_ids := false
	var has_missing_break_cleanup := false
	var has_missing_expire_cleanup := false
	var has_break_trigger_error := false
	var has_expire_trigger_error := false
	for error_msg in errors:
		var msg := str(error_msg)
		has_missing_effect_ids = has_missing_effect_ids or msg.find("field[test_domain_missing_cleanup].effect_ids must not be empty for domain field") != -1
		has_missing_break_cleanup = has_missing_break_cleanup or msg.find("field[test_domain_missing_cleanup].on_break_effect_ids must not be empty for domain field") != -1
		has_missing_expire_cleanup = has_missing_expire_cleanup or msg.find("field[test_domain_missing_cleanup].on_expire_effect_ids must not be empty for domain field") != -1
		has_break_trigger_error = has_break_trigger_error or msg.find("field[test_domain_trigger_mismatch].on_break_effect_ids effect[test_domain_wrong_break_effect] must declare trigger_names including field_break") != -1
		has_expire_trigger_error = has_expire_trigger_error or msg.find("field[test_domain_trigger_mismatch].on_expire_effect_ids effect[test_domain_wrong_expire_effect] must declare trigger_names including field_expire") != -1
	if not (has_missing_effect_ids and has_missing_break_cleanup and has_missing_expire_cleanup and has_break_trigger_error and has_expire_trigger_error):
		return harness.fail_result("domain field contract validation errors missing expected categories")
	return harness.pass_result()
