extends RefCounted

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func validate(errors: Array, effect_id: String, payload, content_index, _dispatcher) -> void:
	if int(payload.amount) <= 0:
		errors.append("effect[%s].damage amount must be > 0, got %d" % [effect_id, int(payload.amount)])
	if bool(payload.use_formula):
		var formula_damage_kind := String(payload.damage_kind)
		if formula_damage_kind != ContentSchemaScript.DAMAGE_KIND_PHYSICAL and formula_damage_kind != ContentSchemaScript.DAMAGE_KIND_SPECIAL:
			errors.append("effect[%s].damage invalid damage_kind for formula: %s" % [effect_id, formula_damage_kind])
	elif not String(payload.combat_type_id).is_empty() and not content_index.combat_types.has(String(payload.combat_type_id)):
		errors.append("effect[%s].damage combat_type_id missing combat type: %s" % [effect_id, String(payload.combat_type_id)])
