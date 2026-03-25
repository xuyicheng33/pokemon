extends RefCounted
class_name DamageService

func calc_base_damage(_level: int, _power: int, _attack_value: int, _defense_value: int) -> int:
    assert(false, "DamageService.calc_base_damage not implemented")
    return 0

func apply_final_mod(_base_damage: int, _final_multiplier: float) -> int:
    assert(false, "DamageService.apply_final_mod not implemented")
    return 0
