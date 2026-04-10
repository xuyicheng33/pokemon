extends RefCounted

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")

const BASE_WIRING_SPECS := [
	{"owner": "trigger_dispatcher", "dependency": "id_factory", "source": "id_factory"},
	{"owner": "trigger_batch_runner", "dependency": "passive_skill_service", "source": "passive_skill_service"},
	{"owner": "trigger_batch_runner", "dependency": "passive_item_service", "source": "passive_item_service"},
	{"owner": "trigger_batch_runner", "dependency": "field_service", "source": "field_service"},
	{"owner": "trigger_batch_runner", "dependency": "effect_instance_dispatcher", "source": "effect_instance_dispatcher"},
	{"owner": "trigger_batch_runner", "dependency": "effect_queue_service", "source": "effect_queue_service"},
	{"owner": "trigger_batch_runner", "dependency": "payload_executor", "source": "payload_executor"},
	{"owner": "trigger_batch_runner", "dependency": "rng_service", "source": "rng_service"},
	{"owner": "effect_instance_service", "dependency": "id_factory", "source": "id_factory"},
	{"owner": "effect_instance_dispatcher", "dependency": "id_factory", "source": "id_factory"},
	{"owner": "rule_mod_service", "dependency": "id_factory", "source": "id_factory"},
	{"owner": "payload_executor", "dependency": "effect_precondition_service", "source": "effect_precondition_service"},
	{"owner": "payload_executor", "dependency": "payload_handler_registry", "source": "payload_handler_registry"},
]

static func wiring_specs() -> Array:
	return PayloadContractRegistryScript.registry_wiring_specs() + BASE_WIRING_SPECS.duplicate(true)
