extends RefCounted

func validate(errors: Array, effect_id: String, payload, _content_index: BattleContentIndex, _dispatcher) -> void:
	if String(payload.resource_key) != "mp":
		errors.append("effect[%s].resource_mod invalid resource_key: %s" % [effect_id, payload.resource_key])
