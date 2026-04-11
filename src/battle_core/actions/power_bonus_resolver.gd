extends RefCounted
class_name PowerBonusResolver

const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")

static func registered_sources() -> PackedStringArray:
	return PowerBonusSourceRegistryScript.registered_sources()

static func unresolved_registered_sources() -> PackedStringArray:
	return PowerBonusSourceRegistryScript.unresolved_runtime_sources()

func resolve_power_bonus(skill_definition, actor, target, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
	return PowerBonusSourceRegistryScript.resolve_power_bonus(
		skill_definition,
		actor,
		target,
		actor_mp_after_cost,
		target_mp_before_cast
	)
