extends RefCounted
class_name PayloadHandlerRegistry

const DependencyContractHelperScript := preload("res://src/shared/dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "payload_damage_handler",
		"source": "payload_damage_handler",
		"nested": true,
	},
	{
		"field": "payload_heal_handler",
		"source": "payload_heal_handler",
		"nested": true,
	},
	{
		"field": "payload_resource_mod_handler",
		"source": "payload_resource_mod_handler",
		"nested": true,
	},
	{
		"field": "payload_stat_mod_handler",
		"source": "payload_stat_mod_handler",
		"nested": true,
	},
	{
		"field": "payload_apply_field_handler",
		"source": "payload_apply_field_handler",
		"nested": true,
	},
	{
		"field": "payload_apply_effect_handler",
		"source": "payload_apply_effect_handler",
		"nested": true,
	},
	{
		"field": "payload_remove_effect_handler",
		"source": "payload_remove_effect_handler",
		"nested": true,
	},
	{
		"field": "payload_rule_mod_handler",
		"source": "payload_rule_mod_handler",
		"nested": true,
	},
	{
		"field": "payload_forced_replace_handler",
		"source": "payload_forced_replace_handler",
		"nested": true,
	},
]

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")

var _handlers: Dictionary = {}

func resolve_missing_dependency() -> String:
	return DependencyContractHelperScript.resolve_missing_dependency(self)


func handler_for(payload) -> Variant:
	if payload == null:
		return null
	var handler_slot := PayloadContractRegistryScript.handler_slot_for_payload(payload)
	return handler_by_slot(handler_slot)

func registered_payload_script_paths() -> PackedStringArray:
	return PayloadContractRegistryScript.registered_payload_script_paths()

func registered_handler_slots() -> PackedStringArray:
	return PayloadContractRegistryScript.registered_handler_slots()

func handler_by_slot(handler_slot: String) -> Variant:
	if handler_slot.is_empty():
		return null
	return _handlers.get(handler_slot, null)

func _get_property_list() -> Array:
	var properties: Array = []
	for slot_name in registered_handler_slots():
		properties.append({
			"name": String(slot_name),
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return properties

func _get(property):
	return handler_by_slot(String(property))

func _set(property, value) -> bool:
	var property_name := String(property)
	if not _has_handler_slot(property_name):
		return false
	_handlers[property_name] = value
	return true

func _has_handler_slot(handler_slot: String) -> bool:
	for slot_name in registered_handler_slots():
		if String(slot_name) == handler_slot:
			return true
	return false
