extends RefCounted

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const EffectPayloadScript := preload("res://src/battle_core/content/effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

const FACT_INCOMING_ACCURACY := "incoming_accuracy"
const FACT_NULLIFY_FIELD_ACCURACY := "nullify_field_accuracy"
const FACT_INCOMING_HEAL_FINAL_MOD := "incoming_heal_final_mod"
const FACT_MISSING_HP := "missing_hp"
const FACT_PERSISTENT_STAT_STAGES := "persistent_stat_stages"

func collect_resource_facts(fact_sources: Dictionary, rel_path: String, resource, register_fact: Callable) -> void:
	if resource is EffectDefinitionScript:
		for payload in resource.payloads:
			_collect_payload_facts(fact_sources, rel_path, payload, register_fact)
		return
	if resource is EffectPayloadScript:
		_collect_payload_facts(fact_sources, rel_path, resource, register_fact)

func _collect_payload_facts(fact_sources: Dictionary, rel_path: String, payload, register_fact: Callable) -> void:
	if payload is RuleModPayloadScript:
		match String(payload.mod_kind):
			FACT_INCOMING_ACCURACY:
				register_fact.call(fact_sources, FACT_INCOMING_ACCURACY, rel_path)
			FACT_NULLIFY_FIELD_ACCURACY:
				register_fact.call(fact_sources, FACT_NULLIFY_FIELD_ACCURACY, rel_path)
			FACT_INCOMING_HEAL_FINAL_MOD:
				register_fact.call(fact_sources, FACT_INCOMING_HEAL_FINAL_MOD, rel_path)
	if payload is HealPayloadScript and bool(payload.use_percent) and String(payload.percent_base) == FACT_MISSING_HP:
		register_fact.call(fact_sources, FACT_MISSING_HP, rel_path)
	if payload is StatModPayloadScript and String(payload.retention_mode) == "persist_on_switch":
		register_fact.call(fact_sources, FACT_PERSISTENT_STAT_STAGES, rel_path)
