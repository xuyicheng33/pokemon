extends RefCounted

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")

const FACT_EFFECT_STACK_SUM := "effect_stack_sum"
const FACT_ONCE_PER_BATTLE := "once_per_battle"
const FACT_EXECUTE_TARGET_HP_RATIO_LTE := "execute_target_hp_ratio_lte"
const FACT_EXECUTE_REQUIRED_TOTAL_STACKS := "execute_required_total_stacks"
const FACT_DAMAGE_SEGMENTS := "damage_segments"

func collect_resource_facts(fact_sources: Dictionary, rel_path: String, resource, register_fact: Callable) -> void:
	if not (resource is SkillDefinitionScript):
		return
	var skill_definition = resource
	if String(skill_definition.power_bonus_source) == PowerBonusSourceRegistryScript.EFFECT_STACK_SUM:
		register_fact.call(fact_sources, FACT_EFFECT_STACK_SUM, rel_path)
	if bool(skill_definition.once_per_battle):
		register_fact.call(fact_sources, FACT_ONCE_PER_BATTLE, rel_path)
	if float(skill_definition.execute_target_hp_ratio_lte) > 0.0:
		register_fact.call(fact_sources, FACT_EXECUTE_TARGET_HP_RATIO_LTE, rel_path)
	if int(skill_definition.execute_required_total_stacks) > 0:
		register_fact.call(fact_sources, FACT_EXECUTE_REQUIRED_TOTAL_STACKS, rel_path)
	if not skill_definition.damage_segments.is_empty():
		register_fact.call(fact_sources, FACT_DAMAGE_SEGMENTS, rel_path)
