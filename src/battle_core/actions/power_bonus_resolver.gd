extends RefCounted
class_name PowerBonusResolver

const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")
const MP_DIFF_CLAMPED := PowerBonusSourceRegistryScript.MP_DIFF_CLAMPED

static func registered_sources() -> PackedStringArray:
	return PowerBonusSourceRegistryScript.registered_sources()

func resolve_power_bonus(skill_definition, actor, target, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
	if skill_definition == null:
		return 0
	match String(skill_definition.power_bonus_source):
		"":
			return 0
		MP_DIFF_CLAMPED:
			if actor == null or target == null:
				return 0
			return max(0, actor_mp_after_cost - target_mp_before_cast)
		_:
			return 0
