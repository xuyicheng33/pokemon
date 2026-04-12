extends RefCounted

func validate(errors: Array, effect_id: String, payload, _content_index, _dispatcher) -> void:
	if bool(payload.use_percent):
		if int(payload.percent) < 1 or int(payload.percent) > 100:
			errors.append("effect[%s].heal percent out of range: %d" % [effect_id, int(payload.percent)])
		var percent_base := String(payload.percent_base)
		if percent_base != "max_hp" and percent_base != "missing_hp":
			errors.append("effect[%s].heal invalid percent_base: %s" % [effect_id, percent_base])
	elif int(payload.amount) <= 0:
		errors.append("effect[%s].heal amount must be > 0, got %d" % [effect_id, int(payload.amount)])
