extends RefCounted

func validate(errors: Array, effect_id: String, payload, content_index, dispatcher) -> void:
	if String(payload.field_definition_id).is_empty() or not content_index.fields.has(payload.field_definition_id):
		errors.append("effect[%s].apply_field missing field: %s" % [effect_id, payload.field_definition_id])
	dispatcher.validate_effect_refs(
		errors,
		"effect[%s].apply_field.on_success_effect_ids" % effect_id,
		payload.on_success_effect_ids,
		content_index.effects
	)
