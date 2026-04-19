extends RefCounted

func validate(errors: Array, effect_id: String, payload, content_index: BattleContentIndex, _dispatcher) -> void:
	if String(payload.effect_definition_id).is_empty() or not content_index.effects.has(payload.effect_definition_id):
		errors.append("effect[%s].apply_effect missing effect: %s" % [effect_id, payload.effect_definition_id])
