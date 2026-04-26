extends RefCounted
class_name BattleCorePayloadServiceSpecs

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")
const PayloadHandlerRegistryScript := preload("res://src/battle_core/effects/payload_handler_registry.gd")
const PayloadUnitTargetHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_unit_target_helper.gd")
const PayloadEffectEventHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_effect_event_helper.gd")
const PayloadRuntimeServiceRegistryScript := preload("res://src/composition/battle_core_payload_runtime_service_registry.gd")

const PayloadDamageHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_damage_handler.gd")
const PayloadHealHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_heal_handler.gd")
const PayloadResourceModHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_resource_mod_handler.gd")
const PayloadStatModHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_stat_mod_handler.gd")
const PayloadApplyFieldHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_apply_field_handler.gd")
const PayloadApplyEffectHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_apply_effect_handler.gd")
const PayloadRemoveEffectHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_remove_effect_handler.gd")
const PayloadRuleModHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_rule_mod_handler.gd")
const PayloadForcedReplaceHandlerScript := preload("res://src/battle_core/effects/payload_handlers/payload_forced_replace_handler.gd")

const HANDLER_SERVICE_DESCRIPTORS := [
	{"slot": "payload_damage_handler", "script": PayloadDamageHandlerScript},
	{"slot": "payload_heal_handler", "script": PayloadHealHandlerScript},
	{"slot": "payload_resource_mod_handler", "script": PayloadResourceModHandlerScript},
	{"slot": "payload_stat_mod_handler", "script": PayloadStatModHandlerScript},
	{"slot": "payload_apply_field_handler", "script": PayloadApplyFieldHandlerScript},
	{"slot": "payload_apply_effect_handler", "script": PayloadApplyEffectHandlerScript},
	{"slot": "payload_remove_effect_handler", "script": PayloadRemoveEffectHandlerScript},
	{"slot": "payload_rule_mod_handler", "script": PayloadRuleModHandlerScript},
	{"slot": "payload_forced_replace_handler", "script": PayloadForcedReplaceHandlerScript},
]

const SHARED_SERVICE_DESCRIPTORS := [
	{"slot": "payload_handler_registry", "script": PayloadHandlerRegistryScript},
	{"slot": "payload_unit_target_helper", "script": PayloadUnitTargetHelperScript},
	{"slot": "payload_effect_event_helper", "script": PayloadEffectEventHelperScript},
]

static func service_descriptors() -> Array:
	var descriptors := SHARED_SERVICE_DESCRIPTORS.duplicate(true)
	descriptors += PayloadRuntimeServiceRegistryScript.descriptors()
	var handler_script_by_slot := _handler_script_by_slot()
	for payload_descriptor in PayloadContractRegistryScript.descriptors():
		var handler_slot := String(payload_descriptor.get("handler_slot", ""))
		if handler_slot.is_empty():
			continue
		assert(handler_script_by_slot.has(handler_slot), "payload handler slot missing static preload binding: %s" % handler_slot)
		descriptors.append({
			"slot": handler_slot,
			"script": handler_script_by_slot[handler_slot],
		})
	return descriptors

static func _handler_script_by_slot() -> Dictionary:
	var handler_script_by_slot: Dictionary = {}
	for handler_descriptor in HANDLER_SERVICE_DESCRIPTORS:
		var handler_slot := String(handler_descriptor.get("slot", ""))
		if handler_slot.is_empty():
			continue
		handler_script_by_slot[handler_slot] = handler_descriptor.get("script", null)
	return handler_script_by_slot
