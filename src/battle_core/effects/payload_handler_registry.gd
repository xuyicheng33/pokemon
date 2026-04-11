extends RefCounted
class_name PayloadHandlerRegistry

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")

var _handlers: Dictionary = {}

func resolve_missing_dependency() -> String:
	for slot_name in registered_handler_slots():
		var handler = handler_by_slot(String(slot_name))
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
