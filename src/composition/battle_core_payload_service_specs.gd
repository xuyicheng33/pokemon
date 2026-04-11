extends RefCounted
class_name BattleCorePayloadServiceSpecs

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")
const PayloadHandlerRegistryScript := preload("res://src/battle_core/effects/payload_handler_registry.gd")
const PayloadUnitTargetHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_unit_target_helper.gd")
const PayloadEffectEventHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_effect_event_helper.gd")
const PayloadDamageHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_damage_handler.gd")
const PayloadHealHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_heal_handler.gd")
const PayloadResourceModHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_resource_mod_handler.gd")
const PayloadStatModHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_stat_mod_handler.gd")
const PayloadApplyFieldHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_apply_field_handler.gd")
const PayloadApplyEffectHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_apply_effect_handler.gd")
const PayloadRemoveEffectHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_remove_effect_handler.gd")
const PayloadRuleModHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_rule_mod_handler.gd")
const PayloadForcedReplaceHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_forced_replace_handler.gd")
const PayloadDamageRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_damage_runtime_service.gd")
const PayloadResourceRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_resource_runtime_service.gd")
const PayloadStatModRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_stat_mod_runtime_service.gd")

const SHARED_SERVICE_DESCRIPTORS := [
	{"slot": "payload_handler_registry", "script": PayloadHandlerRegistryScript},
	{"slot": "payload_unit_target_helper", "script": PayloadUnitTargetHelperScript},
	{"slot": "payload_effect_event_helper", "script": PayloadEffectEventHelperScript},
	{
		"slot": "payload_damage_runtime_service",
		"script": PayloadDamageRuntimeServiceScript,
		"dependencies": [
			{"dependency": "battle_logger", "source": "battle_logger"},
			{"dependency": "log_event_builder", "source": "log_event_builder"},
			{"dependency": "damage_service", "source": "damage_service"},
			{"dependency": "combat_type_service", "source": "combat_type_service"},
			{"dependency": "stat_calculator", "source": "stat_calculator"},
			{"dependency": "rule_mod_service", "source": "rule_mod_service"},
			{"dependency": "faint_killer_attribution_service", "source": "faint_killer_attribution_service"},
			{"dependency": "target_helper", "source": "payload_unit_target_helper"},
			{"dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
		],
	},
	{
		"slot": "payload_resource_runtime_service",
		"script": PayloadResourceRuntimeServiceScript,
		"dependencies": [
			{"dependency": "battle_logger", "source": "battle_logger"},
			{"dependency": "log_event_builder", "source": "log_event_builder"},
			{"dependency": "target_helper", "source": "payload_unit_target_helper"},
			{"dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
			{"dependency": "rule_mod_service", "source": "rule_mod_service"},
		],
	},
	{
		"slot": "payload_stat_mod_runtime_service",
		"script": PayloadStatModRuntimeServiceScript,
		"dependencies": [
			{"dependency": "battle_logger", "source": "battle_logger"},
			{"dependency": "log_event_builder", "source": "log_event_builder"},
			{"dependency": "target_helper", "source": "payload_unit_target_helper"},
			{"dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
		],
	},
]

const HANDLER_SCRIPTS_BY_SLOT := {
	"payload_damage_handler": PayloadDamageHandlerScript,
	"payload_heal_handler": PayloadHealHandlerScript,
	"payload_resource_mod_handler": PayloadResourceModHandlerScript,
	"payload_stat_mod_handler": PayloadStatModHandlerScript,
	"payload_apply_field_handler": PayloadApplyFieldHandlerScript,
	"payload_apply_effect_handler": PayloadApplyEffectHandlerScript,
	"payload_remove_effect_handler": PayloadRemoveEffectHandlerScript,
	"payload_rule_mod_handler": PayloadRuleModHandlerScript,
	"payload_forced_replace_handler": PayloadForcedReplaceHandlerScript,
}

static func service_descriptors() -> Array:
	var descriptors := SHARED_SERVICE_DESCRIPTORS.duplicate(true)
	for payload_descriptor in PayloadContractRegistryScript.descriptors():
		var handler_slot := String(payload_descriptor.get("handler_slot", ""))
		var handler_script = HANDLER_SCRIPTS_BY_SLOT.get(handler_slot, null)
		if handler_script == null:
			continue
		descriptors.append({
			"slot": handler_slot,
			"script": handler_script,
		})
	return descriptors

static func shared_service_wiring_specs() -> Array:
	var wiring_specs: Array = []
	for descriptor in SHARED_SERVICE_DESCRIPTORS:
		var owner := String(descriptor.get("slot", ""))
		for raw_dependency_spec in Array(descriptor.get("dependencies", [])):
			var dependency_spec := Dictionary(raw_dependency_spec)
			wiring_specs.append({
				"owner": owner,
				"dependency": String(dependency_spec.get("dependency", "")),
				"source": String(dependency_spec.get("source", "")),
			})
	return wiring_specs
