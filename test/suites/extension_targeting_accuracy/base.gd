extends "res://test/support/gdunit_suite_bridge.gd"

const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const EffectEventScript := preload("res://src/battle_core/contracts/effect_event.gd")
const EffectSourceMetaHelperScript := preload("res://src/battle_core/effects/effect_source_meta_helper.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func _has_event(event_log: Array, predicate: Callable) -> bool:
	for log_event in event_log:
		if predicate.call(log_event):
			return true
	return false
