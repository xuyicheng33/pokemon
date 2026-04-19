extends RefCounted

func validate(errors: Array, effect_id: String, payload, content_index: BattleContentIndex, _dispatcher) -> void:
	if String(payload.effect_definition_id).is_empty() or not content_index.effects.has(payload.effect_definition_id):
		errors.append("effect[%s].remove_effect missing effect: %s" % [effect_id, payload.effect_definition_id])
	if String(payload.remove_mode) != "single" and String(payload.remove_mode) != "all":
		errors.append("effect[%s].remove_effect invalid remove_mode: %s" % [effect_id, String(payload.remove_mode)])
