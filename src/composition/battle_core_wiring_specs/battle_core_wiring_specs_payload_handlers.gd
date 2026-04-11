extends RefCounted

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")
const PayloadServiceSpecsScript := preload("res://src/composition/battle_core_payload_service_specs.gd")

static func wiring_specs() -> Array:
	return PayloadContractRegistryScript.handler_wiring_specs() + PayloadServiceSpecsScript.shared_service_wiring_specs()
