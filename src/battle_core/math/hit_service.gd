extends RefCounted
class_name HitService

## roll_hit 必中分支也消费一次 rng.next_float()，确保 rng_stream_index 单调；
## 未来 rule_mod 把 100 改到 95 时不会引入额外消费导致回放漂移。
func roll_hit(accuracy: int, rng_service: RngService) -> Dictionary:
	if accuracy < 0:
		push_error("HitService.roll_hit: accuracy must be >= 0, got %d" % accuracy)
		assert(false, "HitService.roll_hit accuracy < 0")
	var hit_rate: float = clamp(float(accuracy) / 100.0, 0.0, 1.0)
	var hit_roll: float = rng_service.next_float()
	if accuracy >= 100:
		return {
			"hit": true,
			"hit_roll": null,
			"hit_rate": hit_rate,
		}
	return {
		"hit": hit_roll < hit_rate,
		"hit_roll": hit_roll,
		"hit_rate": hit_rate,
	}
