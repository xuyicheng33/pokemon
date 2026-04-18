extends RefCounted
class_name StatCalculator

func calc_effective_stat(base_value: int, stage_delta: int) -> int:
	var clamped_stage: int = clamp(stage_delta, -2, 2)
	var multiplier: float = 1.0
	if clamped_stage >= 0:
		multiplier = float(2 + clamped_stage) / 2.0
	else:
		multiplier = 2.0 / float(2 - clamped_stage)
	return max(1, int(floor(float(base_value) * multiplier)))
