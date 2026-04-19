extends RefCounted

func validate(errors: Array, effect_id: String, payload, _content_index: BattleContentIndex, _dispatcher) -> void:
	if payload.scope != "self" and payload.scope != "target":
		errors.append("effect[%s].forced_replace invalid scope: %s" % [effect_id, payload.scope])
	if String(payload.selector_reason).strip_edges().is_empty():
		errors.append("effect[%s].forced_replace selector_reason must not be empty" % effect_id)
