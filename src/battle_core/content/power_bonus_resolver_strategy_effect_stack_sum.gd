extends RefCounted

func resolve_power_bonus(skill_definition, actor, target, _actor_mp_after_cost: int, _target_mp_before_cast: int) -> int:
	if skill_definition == null:
		return 0
	var per_stack := int(skill_definition.power_bonus_per_stack)
	if per_stack <= 0:
		return 0
	var total_stacks := _count_matching_effect_instances(actor, skill_definition.power_bonus_self_effect_ids)
	total_stacks += _count_matching_effect_instances(target, skill_definition.power_bonus_target_effect_ids)
	return total_stacks * per_stack

func _count_matching_effect_instances(unit_state, effect_ids: PackedStringArray) -> int:
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
