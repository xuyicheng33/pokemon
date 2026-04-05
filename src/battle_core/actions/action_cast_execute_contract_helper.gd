extends RefCounted
class_name ActionCastExecuteContractHelper

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
	return count_matching_effect_instances(actor, skill_definition.execute_self_effect_ids) \
		+ count_matching_effect_instances(target, skill_definition.execute_target_effect_ids)

static func count_matching_effect_instances(unit_state, effect_ids: PackedStringArray) -> int:
	if unit_state == null or effect_ids.is_empty():
		return 0
	var allowed_effect_ids: Dictionary = {}
	for effect_id in effect_ids:
		var normalized_effect_id := String(effect_id).strip_edges()
		if normalized_effect_id.is_empty():
			continue
		allowed_effect_ids[normalized_effect_id] = true
	var count := 0
	for effect_instance in unit_state.effect_instances:
		if allowed_effect_ids.has(String(effect_instance.def_id)):
			count += 1
	return count
