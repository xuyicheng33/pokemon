extends RefCounted
class_name PowerBonusSourceRegistry

const MP_DIFF_CLAMPED := "mp_diff_clamped"
const EFFECT_STACK_SUM := "effect_stack_sum"

static func registered_sources() -> PackedStringArray:
	return PackedStringArray(["", MP_DIFF_CLAMPED, EFFECT_STACK_SUM])

static func unresolved_runtime_sources() -> PackedStringArray:
	var unresolved := PackedStringArray()
	for raw_source in registered_sources():
		var source := String(raw_source)
		if _runtime_source_supported(source):
			continue
		unresolved.append(source)
	return unresolved

static func validate_skill_contract(errors: Array, skill_id: String, skill_definition, content_index) -> void:
	match String(skill_definition.power_bonus_source):
		"":
			return
		EFFECT_STACK_SUM:
			_validate_effect_stack_sum_contract(errors, skill_id, skill_definition, content_index)

static func resolve_power_bonus(skill_definition, actor, target, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
	if skill_definition == null:
		return 0
	match String(skill_definition.power_bonus_source):
		"":
			return 0
		MP_DIFF_CLAMPED:
			if actor == null or target == null:
				return 0
			return max(0, actor_mp_after_cost - target_mp_before_cast)
		EFFECT_STACK_SUM:
			return _resolve_effect_stack_sum(skill_definition, actor, target)
		_:
			return 0

static func _runtime_source_supported(source: String) -> bool:
	return source.is_empty() or source == MP_DIFF_CLAMPED or source == EFFECT_STACK_SUM

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

static func _resolve_effect_stack_sum(skill_definition, actor, target) -> int:
	if skill_definition == null:
		return 0
	var per_stack := int(skill_definition.power_bonus_per_stack)
	if per_stack <= 0:
		return 0
	var total_stacks := _count_matching_effect_instances(actor, skill_definition.power_bonus_self_effect_ids)
	total_stacks += _count_matching_effect_instances(target, skill_definition.power_bonus_target_effect_ids)
	return total_stacks * per_stack

static func _count_matching_effect_instances(unit_state, effect_ids: PackedStringArray) -> int:
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
