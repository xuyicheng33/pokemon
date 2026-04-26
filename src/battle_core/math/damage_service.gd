extends RefCounted
class_name DamageService

func calc_base_damage(level: int, power: int, attack_value: int, defense_value: int) -> int:
	var safe_defense: int = max(1, defense_value)
	var level_factor: int = int(floor((2.0 * float(level)) / 5.0 + 2.0))
	return int(floor(floor(float(level_factor * power * attack_value) / float(safe_defense)) / 50.0)) + 2

## 设计选择：命中后伤害下限固定为 1（"无属性免疫" + "0 伤地板=1"）；如需 final_mod=0 模拟 0 伤需显式改这一处。
func apply_final_mod(base_damage: int, final_multiplier: float) -> int:
	var protected_damage: float = max(0.0, float(base_damage) * final_multiplier)
	return max(1, int(floor(protected_damage)))
