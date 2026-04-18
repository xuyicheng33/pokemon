extends RefCounted
class_name PayloadEffectEventHelper

func resolve_effect_roll(effect_event) -> Variant:
	return null if effect_event == null else effect_event.sort_random_roll
