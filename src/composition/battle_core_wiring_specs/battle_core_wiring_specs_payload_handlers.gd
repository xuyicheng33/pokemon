extends RefCounted

const PayloadContractRegistryScript := preload("res://src/battle_core/content/payload_contract_registry.gd")

const BASE_WIRING_SPECS := [
	{"owner": "payload_damage_runtime_service", "dependency": "battle_logger", "source": "battle_logger"},
	{"owner": "payload_damage_runtime_service", "dependency": "log_event_builder", "source": "log_event_builder"},
	{"owner": "payload_damage_runtime_service", "dependency": "damage_service", "source": "damage_service"},
	{"owner": "payload_damage_runtime_service", "dependency": "combat_type_service", "source": "combat_type_service"},
	{"owner": "payload_damage_runtime_service", "dependency": "stat_calculator", "source": "stat_calculator"},
	{"owner": "payload_damage_runtime_service", "dependency": "rule_mod_service", "source": "rule_mod_service"},
	{"owner": "payload_damage_runtime_service", "dependency": "faint_killer_attribution_service", "source": "faint_killer_attribution_service"},
	{"owner": "payload_damage_runtime_service", "dependency": "target_helper", "source": "payload_unit_target_helper"},
	{"owner": "payload_damage_runtime_service", "dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
	{"owner": "payload_resource_runtime_service", "dependency": "battle_logger", "source": "battle_logger"},
	{"owner": "payload_resource_runtime_service", "dependency": "log_event_builder", "source": "log_event_builder"},
	{"owner": "payload_resource_runtime_service", "dependency": "target_helper", "source": "payload_unit_target_helper"},
	{"owner": "payload_resource_runtime_service", "dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
	{"owner": "payload_resource_runtime_service", "dependency": "rule_mod_service", "source": "rule_mod_service"},
	{"owner": "payload_stat_mod_runtime_service", "dependency": "battle_logger", "source": "battle_logger"},
	{"owner": "payload_stat_mod_runtime_service", "dependency": "log_event_builder", "source": "log_event_builder"},
	{"owner": "payload_stat_mod_runtime_service", "dependency": "target_helper", "source": "payload_unit_target_helper"},
	{"owner": "payload_stat_mod_runtime_service", "dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
]

static func wiring_specs() -> Array:
	return PayloadContractRegistryScript.handler_wiring_specs() + BASE_WIRING_SPECS.duplicate(true)
