extends RefCounted
class_name PowerBonusResolver

const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")
const ZERO_RESOLVER_KIND := PowerBonusSourceRegistryScript.RESOLVER_KIND_ZERO
const MP_DIFF_CLAMPED_RESOLVER_KIND := PowerBonusSourceRegistryScript.RESOLVER_KIND_MP_DIFF_CLAMPED
const EFFECT_STACK_SUM_RESOLVER_KIND := PowerBonusSourceRegistryScript.RESOLVER_KIND_EFFECT_STACK_SUM

static func registered_sources() -> PackedStringArray:
	return PowerBonusSourceRegistryScript.registered_sources()

static func supported_resolver_kinds() -> PackedStringArray:
	return PackedStringArray([
		ZERO_RESOLVER_KIND,
		MP_DIFF_CLAMPED_RESOLVER_KIND,
		EFFECT_STACK_SUM_RESOLVER_KIND,
	])

static func unresolved_registered_sources() -> PackedStringArray:
	var unresolved := PackedStringArray()
	for raw_source in registered_sources():
		var resolver_kind := PowerBonusSourceRegistryScript.resolver_kind_for_source(String(raw_source))
		if supported_resolver_kinds().has(resolver_kind):
			continue
		unresolved.append(String(raw_source))
	return unresolved

func resolve_power_bonus(skill_definition, actor, target, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
	if skill_definition == null:
		return 0
	match PowerBonusSourceRegistryScript.resolver_kind_for_source(String(skill_definition.power_bonus_source)):
		ZERO_RESOLVER_KIND:
			return 0
		MP_DIFF_CLAMPED_RESOLVER_KIND:
			if actor == null or target == null:
				return 0
			return max(0, actor_mp_after_cost - target_mp_before_cast)
		EFFECT_STACK_SUM_RESOLVER_KIND:
			return _resolve_effect_stack_sum(skill_definition, actor, target)
		_:
			return 0

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
