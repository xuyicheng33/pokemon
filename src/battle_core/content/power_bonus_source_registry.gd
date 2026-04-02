extends RefCounted
class_name PowerBonusSourceRegistry

const MP_DIFF_CLAMPED := "mp_diff_clamped"
const EFFECT_STACK_SUM := "effect_stack_sum"

static func registered_sources() -> PackedStringArray:
    return PackedStringArray(["", MP_DIFF_CLAMPED, EFFECT_STACK_SUM])
