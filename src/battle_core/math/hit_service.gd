extends RefCounted
class_name HitService

func roll_hit(accuracy: int, rng_service: RngService) -> Dictionary:
	var hit_rate: float = clamp(float(accuracy) / 100.0, 0.0, 1.0)
	if accuracy >= 100:
		return {
			"hit": true,
			"hit_roll": null,
			"hit_rate": hit_rate,
		}
	var hit_roll: float = rng_service.next_float()
	return {
		"hit": hit_roll < hit_rate,
		"hit_roll": hit_roll,
		"hit_rate": hit_rate,
	}
