extends RefCounted

const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")

const FACT_FIELD_CREATOR_ACCURACY_OVERRIDE := "field_creator_accuracy_override"
const FACT_FIELD_EXPIRE_EFFECTS := "field_expire_effects"
const FACT_FIELD_BREAK_EFFECTS := "field_break_effects"

func collect_resource_facts(fact_sources: Dictionary, rel_path: String, resource, register_fact: Callable) -> void:
	if not (resource is FieldDefinitionScript):
		return
	var field_definition = resource
	if int(field_definition.creator_accuracy_override) > 0:
		register_fact.call(fact_sources, FACT_FIELD_CREATOR_ACCURACY_OVERRIDE, rel_path)
	if not field_definition.on_expire_effect_ids.is_empty():
		register_fact.call(fact_sources, FACT_FIELD_EXPIRE_EFFECTS, rel_path)
	if not field_definition.on_break_effect_ids.is_empty():
		register_fact.call(fact_sources, FACT_FIELD_BREAK_EFFECTS, rel_path)
