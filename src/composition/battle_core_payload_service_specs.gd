extends RefCounted
class_name BattleCorePayloadServiceSpecs

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")
const PayloadHandlerRegistryScript := preload("res://src/battle_core/effects/payload_handler_registry.gd")
const PayloadUnitTargetHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_unit_target_helper.gd")
const PayloadEffectEventHelperScript := preload("res://src/battle_core/effects/payload_handlers/payload_effect_event_helper.gd")
const PayloadRuntimeServiceRegistryScript := preload("res://src/composition/battle_core_payload_runtime_service_registry.gd")
const PAYLOAD_HANDLER_SCRIPT_ROOT := "res://src/battle_core/effects/payload_handlers"

const SHARED_SERVICE_DESCRIPTORS := [
	{"slot": "payload_handler_registry", "script": PayloadHandlerRegistryScript},
	{"slot": "payload_unit_target_helper", "script": PayloadUnitTargetHelperScript},
	{"slot": "payload_effect_event_helper", "script": PayloadEffectEventHelperScript},
]

static func service_descriptors() -> Array:
	var descriptors := SHARED_SERVICE_DESCRIPTORS.duplicate(true)
	descriptors += PayloadRuntimeServiceRegistryScript.descriptors()
	for payload_descriptor in PayloadContractRegistryScript.descriptors():
		var handler_slot := String(payload_descriptor.get("handler_slot", ""))
		if handler_slot.is_empty():
			continue
		descriptors.append(_handler_service_descriptor(handler_slot))
	return descriptors

static func handler_script_path_for_slot(handler_slot: String) -> String:
	var normalized_slot := handler_slot.strip_edges()
	if normalized_slot.is_empty():
		return ""
	return "%s/%s.gd" % [PAYLOAD_HANDLER_SCRIPT_ROOT, normalized_slot]

static func _handler_service_descriptor(handler_slot: String) -> Dictionary:
	return {
		"slot": handler_slot,
		"script": _load_handler_script(handler_slot),
	}

static func _load_handler_script(handler_slot: String) -> Variant:
	var script_path := handler_script_path_for_slot(handler_slot)
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		return null
	return load(script_path)
