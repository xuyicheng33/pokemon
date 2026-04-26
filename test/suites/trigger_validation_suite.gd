extends "res://tests/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")


func test_skill_effect_trigger_validation() -> void:
	var content_index = _build_content_index(_harness)
	var effect = EffectDefinitionScript.new()
	effect.id = "test_skill_trigger_mismatch_effect"
	effect.display_name = "Skill Trigger Mismatch"
	effect.scope = "self"
	effect.trigger_names = PackedStringArray(["on_hit"])
	content_index.register_resource(effect)

	var skill = SkillDefinitionScript.new()
	skill.id = "test_skill_trigger_mismatch_skill"
	skill.display_name = "Skill Trigger Mismatch"
	skill.damage_kind = "none"
	skill.power = 0
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.targeting = "self"
	skill.effects_on_cast_ids = PackedStringArray([effect.id])
	content_index.register_resource(skill)

	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "effects_on_cast_ids effect[%s] must declare trigger_names including on_cast" % effect.id):
		fail("skill direct effect trigger mismatch must fail validation")
		return

func test_field_lifecycle_trigger_validation() -> void:
	var content_index = _build_content_index(_harness)
	var effect = EffectDefinitionScript.new()
	effect.id = "test_field_break_mismatch_effect"
	effect.display_name = "Field Break Trigger Mismatch"
	effect.scope = "self"
	effect.trigger_names = PackedStringArray(["on_hit"])
	content_index.register_resource(effect)

	var field_definition = FieldDefinitionScript.new()
	field_definition.id = "test_field_break_mismatch"
	field_definition.display_name = "Field Break Trigger Mismatch"
	field_definition.on_break_effect_ids = PackedStringArray([effect.id])
	content_index.register_resource(field_definition)

	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "on_break_effect_ids effect[%s] must declare trigger_names including field_break" % effect.id):
		fail("field lifecycle effect trigger mismatch must fail validation")
		return

func test_apply_field_success_trigger_validation() -> void:
	var content_index = _build_content_index(_harness)
	var success_effect = EffectDefinitionScript.new()
	success_effect.id = "test_field_success_mismatch_effect"
	success_effect.display_name = "Field Success Trigger Mismatch"
	success_effect.scope = "target"
	success_effect.trigger_names = PackedStringArray(["on_cast"])
	content_index.register_resource(success_effect)

	var field_definition = FieldDefinitionScript.new()
	field_definition.id = "test_field_success_validation"
	field_definition.display_name = "Field Success Validation"
	content_index.register_resource(field_definition)

	var apply_field_payload = ApplyFieldPayloadScript.new()
	apply_field_payload.payload_type = "apply_field"
	apply_field_payload.field_definition_id = field_definition.id
	apply_field_payload.on_success_effect_ids = PackedStringArray([success_effect.id])

	var apply_effect = EffectDefinitionScript.new()
	apply_effect.id = "test_apply_field_success_effect"
	apply_effect.display_name = "Apply Field Success Validation"
	apply_effect.scope = "field"
	apply_effect.duration_mode = "turns"
	apply_effect.duration = 2
	apply_effect.decrement_on = "turn_end"
	apply_effect.trigger_names = PackedStringArray(["on_hit"])
	apply_effect.payloads.clear()
	apply_effect.payloads.append(apply_field_payload)
	content_index.register_resource(apply_effect)

	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "apply_field.on_success_effect_ids effect[%s] must declare trigger_names including field_apply_success" % success_effect.id):
		fail("apply_field on_success trigger mismatch must fail validation")
		return


func _build_content_index(harness):
	var sample_factory = harness.build_sample_factory()
	return harness.build_loaded_content_index(sample_factory)

func _has_error(errors: Array, expected_message: String) -> bool:
	for raw_error in errors:
		if String(raw_error).contains(expected_message):
			return true
	return false
