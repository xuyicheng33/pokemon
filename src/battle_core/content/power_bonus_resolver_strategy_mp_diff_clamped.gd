extends RefCounted

func resolve_power_bonus(_skill_definition, actor, target, actor_mp_after_cost: int, target_mp_before_cast: int) -> int:
	if actor == null or target == null:
		return 0
	return max(0, actor_mp_after_cost - target_mp_before_cast)
