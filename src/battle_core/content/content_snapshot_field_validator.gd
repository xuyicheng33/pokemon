extends RefCounted
class_name ContentSnapshotFieldValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func validate(content_index: BattleContentIndex, errors: Array, payload_validator) -> void:
	var allowed_field_kinds := PackedStringArray([
		ContentSchemaScript.FIELD_KIND_NORMAL,
		ContentSchemaScript.FIELD_KIND_DOMAIN,
	])
	for field_id in content_index.fields.keys():
		var field_definition = content_index.fields[field_id]
		var field_kind := String(field_definition.field_kind)
		if not allowed_field_kinds.has(field_kind):
			errors.append("field[%s].field_kind invalid: %s" % [field_id, String(field_definition.field_kind)])
		payload_validator.validate_effect_refs(errors, "field[%s].effect_ids" % field_id, field_definition.effect_ids, content_index.effects)
		payload_validator.validate_effect_refs(errors, "field[%s].on_expire_effect_ids" % field_id, field_definition.on_expire_effect_ids, content_index.effects)
		payload_validator.validate_effect_refs(errors, "field[%s].on_break_effect_ids" % field_id, field_definition.on_break_effect_ids, content_index.effects)
		if int(field_definition.creator_accuracy_override) < -1 or int(field_definition.creator_accuracy_override) > 100:
			errors.append("field[%s].creator_accuracy_override out of range: %d" % [field_id, int(field_definition.creator_accuracy_override)])
		if field_kind == ContentSchemaScript.FIELD_KIND_DOMAIN:
			if field_definition.effect_ids.is_empty():
				errors.append("field[%s].effect_ids must not be empty for domain field" % field_id)
			if field_definition.on_expire_effect_ids.is_empty():
				errors.append("field[%s].on_expire_effect_ids must not be empty for domain field" % field_id)
			if field_definition.on_break_effect_ids.is_empty():
				errors.append("field[%s].on_break_effect_ids must not be empty for domain field" % field_id)
