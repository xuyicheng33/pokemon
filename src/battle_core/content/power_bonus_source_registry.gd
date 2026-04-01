extends RefCounted
class_name PowerBonusSourceRegistry

const MP_DIFF_CLAMPED := "mp_diff_clamped"

static func registered_sources() -> PackedStringArray:
    return PackedStringArray(["", MP_DIFF_CLAMPED])
