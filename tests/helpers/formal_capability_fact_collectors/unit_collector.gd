extends RefCounted

const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")

const FACT_UNIT_PASSIVE_SKILL_BINDING := "unit_passive_skill_binding"
const FACT_UNIT_ULTIMATE_SKILL_BINDING := "unit_ultimate_skill_binding"
const FACT_UNIT_CANDIDATE_SKILL_POOL := "unit_candidate_skill_pool"

func collect_resource_facts(fact_sources: Dictionary, rel_path: String, resource, register_fact: Callable) -> void:
	if not (resource is UnitDefinitionScript):
		return
	var unit_definition = resource
	if not String(unit_definition.passive_skill_id).strip_edges().is_empty():
		register_fact.call(fact_sources, FACT_UNIT_PASSIVE_SKILL_BINDING, rel_path)
	if not String(unit_definition.ultimate_skill_id).strip_edges().is_empty():
		register_fact.call(fact_sources, FACT_UNIT_ULTIMATE_SKILL_BINDING, rel_path)
	if not unit_definition.candidate_skill_ids.is_empty():
		register_fact.call(fact_sources, FACT_UNIT_CANDIDATE_SKILL_POOL, rel_path)
