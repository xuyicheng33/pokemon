extends RefCounted

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func validate(errors: Array, effect_id: String, payload, content_index: BattleContentIndex, dispatcher) -> void:
	if String(payload.field_definition_id).is_empty() or not content_index.fields.has(payload.field_definition_id):
		errors.append("effect[%s].apply_field missing field: %s" % [effect_id, payload.field_definition_id])
	var effect_definition = content_index.effects.get(effect_id, null)
	if effect_definition == null:
		errors.append("effect[%s].apply_field missing carrier effect" % effect_id)
	else:
		if String(effect_definition.duration_mode) != ContentSchemaScript.DURATION_TURNS:
			errors.append("effect[%s].apply_field carrier duration_mode must be turns" % effect_id)
		if int(effect_definition.duration) <= 0:
			errors.append("effect[%s].apply_field carrier duration must be > 0" % effect_id)
	dispatcher.validate_effect_refs(
		errors,
		"effect[%s].apply_field.on_success_effect_ids" % effect_id,
		payload.on_success_effect_ids,
		content_index.effects
	)
