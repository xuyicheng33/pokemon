extends RefCounted
class_name ActionCastExecuteContractHelper

const EffectInstanceServiceScript := preload("res://src/battle_core/effects/effect_instance_service.gd")

static func should_execute_skill(actor, target, skill_definition) -> bool:
	if actor == null or target == null or skill_definition == null:
		return false
	if float(skill_definition.execute_target_hp_ratio_lte) <= 0.0:
		return false
	var target_hp_threshold := int(floor(float(target.max_hp) * float(skill_definition.execute_target_hp_ratio_lte)))
	if int(target.current_hp) > target_hp_threshold:
		return false
	var required_total_stacks := int(skill_definition.execute_required_total_stacks)
	if required_total_stacks <= 0:
		return true
	return count_execute_total_stacks(actor, target, skill_definition) >= required_total_stacks

static func count_execute_total_stacks(actor, target, skill_definition) -> int:
	return EffectInstanceServiceScript.count_matching_effect_instances(actor, skill_definition.execute_self_effect_ids) \
		+ EffectInstanceServiceScript.count_matching_effect_instances(target, skill_definition.execute_target_effect_ids)
