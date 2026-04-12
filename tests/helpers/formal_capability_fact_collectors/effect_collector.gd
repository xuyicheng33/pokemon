extends RefCounted

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")

const FACT_REQUIRED_TARGET_EFFECTS := "required_target_effects"
const FACT_REQUIRED_TARGET_SAME_OWNER := "required_target_same_owner"
const FACT_ON_RECEIVE_ACTION_DAMAGE_SEGMENT := "on_receive_action_damage_segment"

func collect_resource_facts(fact_sources: Dictionary, rel_path: String, resource, register_fact: Callable) -> void:
	if not (resource is EffectDefinitionScript):
		return
	var effect_definition = resource
	if not effect_definition.required_target_effects.is_empty():
		register_fact.call(fact_sources, FACT_REQUIRED_TARGET_EFFECTS, rel_path)
	if bool(effect_definition.required_target_same_owner):
		register_fact.call(fact_sources, FACT_REQUIRED_TARGET_SAME_OWNER, rel_path)
	if effect_definition.trigger_names.has(FACT_ON_RECEIVE_ACTION_DAMAGE_SEGMENT):
		register_fact.call(fact_sources, FACT_ON_RECEIVE_ACTION_DAMAGE_SEGMENT, rel_path)
