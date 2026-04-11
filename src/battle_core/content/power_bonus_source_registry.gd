extends RefCounted
class_name PowerBonusSourceRegistry

const MP_DIFF_CLAMPED := "mp_diff_clamped"
const EFFECT_STACK_SUM := "effect_stack_sum"

static func registered_sources() -> PackedStringArray:
	return PackedStringArray(["", MP_DIFF_CLAMPED, EFFECT_STACK_SUM])

static func validate_skill_contract(errors: Array, skill_id: String, skill_definition, content_index) -> void:
	match String(skill_definition.power_bonus_source):
		"":
			return
		EFFECT_STACK_SUM:
			_validate_effect_stack_sum_contract(errors, skill_id, skill_definition, content_index)

static func _validate_effect_stack_sum_contract(errors: Array, skill_id: String, skill_definition, content_index) -> void:
	var has_any_effect_id := false
	for effect_id in skill_definition.power_bonus_self_effect_ids:
		var normalized_effect_id := String(effect_id).strip_edges()
		if normalized_effect_id.is_empty():
			errors.append("skill[%s].power_bonus_self_effect_ids must not contain empty entry" % skill_id)
			continue
		has_any_effect_id = true
		if not content_index.effects.has(normalized_effect_id):
			errors.append("skill[%s].power_bonus_self_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
	for effect_id in skill_definition.power_bonus_target_effect_ids:
		var normalized_effect_id := String(effect_id).strip_edges()
		if normalized_effect_id.is_empty():
			errors.append("skill[%s].power_bonus_target_effect_ids must not contain empty entry" % skill_id)
			continue
		has_any_effect_id = true
		if not content_index.effects.has(normalized_effect_id):
			errors.append("skill[%s].power_bonus_target_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
	if not has_any_effect_id:
		errors.append("skill[%s].effect_stack_sum requires at least one power bonus effect id" % skill_id)
	if int(skill_definition.power_bonus_per_stack) <= 0:
		errors.append("skill[%s].power_bonus_per_stack must be > 0 for effect_stack_sum, got %d" % [skill_id, int(skill_definition.power_bonus_per_stack)])
