extends RefCounted

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")

const FACT_PASSIVE_TRIGGER_BINDING := "passive_trigger_binding"
const FACT_PASSIVE_EFFECT_BINDING := "passive_effect_binding"

func collect_resource_facts(fact_sources: Dictionary, rel_path: String, resource, register_fact: Callable) -> void:
	if not (resource is PassiveSkillDefinitionScript):
		return
	var passive_definition = resource
	if not passive_definition.trigger_names.is_empty():
		register_fact.call(fact_sources, FACT_PASSIVE_TRIGGER_BINDING, rel_path)
	if not passive_definition.effect_ids.is_empty():
		register_fact.call(fact_sources, FACT_PASSIVE_EFFECT_BINDING, rel_path)
