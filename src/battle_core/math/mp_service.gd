extends RefCounted
class_name MpService

func apply_turn_start_regen(current_mp: int, regen_amount: int, max_mp: int) -> int:
    return clamp(current_mp + regen_amount, 0, max_mp)

func consume_mp(current_mp: int, mp_cost: int) -> int:
    return max(0, current_mp - mp_cost)
