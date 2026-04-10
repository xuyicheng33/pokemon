extends RefCounted
class_name PayloadHandlerRegistry

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")

var payload_damage_handler
var payload_heal_handler
var payload_resource_mod_handler
var payload_stat_mod_handler
var payload_apply_field_handler
var payload_apply_effect_handler
var payload_remove_effect_handler
var payload_rule_mod_handler
var payload_forced_replace_handler

func resolve_missing_dependency() -> String:
	for spec in _handler_specs():
		var slot_name := String(spec["slot"])
		var handler = get(slot_name)
		if handler == null:
			return slot_name
		if handler.has_method("resolve_missing_dependency"):
			var missing_dependency := str(handler.resolve_missing_dependency())
			if not missing_dependency.is_empty():
				return "%s.%s" % [slot_name, missing_dependency]
	return ""

func handler_for(payload) -> Variant:
	if payload == null:
		return null
	var handler_slot := PayloadContractRegistryScript.handler_slot_for_payload(payload)
	return null if handler_slot.is_empty() else get(handler_slot)

func registered_payload_script_paths() -> PackedStringArray:
	return PayloadContractRegistryScript.registered_payload_script_paths()

func registered_handler_slots() -> PackedStringArray:
	return PayloadContractRegistryScript.registered_handler_slots()

func _handler_specs() -> Array:
	var specs: Array = []
	for descriptor in PayloadContractRegistryScript.descriptors():
		specs.append({
			"script": descriptor.get("script", null),
			"slot": String(descriptor.get("handler_slot", "")),
		})
	return specs
