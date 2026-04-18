extends "res://test/support/gdunit_suite_bridge.gd"

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const LogCauseTestHelperScript := preload("res://tests/support/log_cause_test_helper.gd")

var _helper = LogCauseTestHelperScript.new()

func _event_id(log_event) -> String:
	return _helper.event_id(log_event)

func _find_event(event_log: Array, predicate: Callable):
	return _helper.find_event(event_log, predicate)
