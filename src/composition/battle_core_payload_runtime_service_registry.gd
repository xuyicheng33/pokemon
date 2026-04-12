extends RefCounted
class_name BattleCorePayloadRuntimeServiceRegistry

const PayloadDamageRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_damage_runtime_service.gd")
const PayloadResourceRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_resource_runtime_service.gd")
const PayloadStatModRuntimeServiceScript := preload("res://src/battle_core/effects/payload_handlers/payload_stat_mod_runtime_service.gd")

const RUNTIME_SERVICE_DESCRIPTORS := [
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

static func descriptors() -> Array:
	return RUNTIME_SERVICE_DESCRIPTORS.duplicate(true)

static func registered_slots() -> PackedStringArray:
	var runtime_service_slots := PackedStringArray()
	for descriptor in RUNTIME_SERVICE_DESCRIPTORS:
		var slot_name := String(descriptor.get("slot", "")).strip_edges()
		if slot_name.is_empty():
			continue
		runtime_service_slots.append(slot_name)
	return runtime_service_slots

static func descriptor_for_slot(slot_name: String) -> Dictionary:
	var normalized_slot := slot_name.strip_edges()
	for descriptor in RUNTIME_SERVICE_DESCRIPTORS:
		if String(descriptor.get("slot", "")).strip_edges() == normalized_slot:
			return descriptor.duplicate(true)
	return {}

static func wiring_specs() -> Array:
	var wiring_specs: Array = []
	for descriptor in RUNTIME_SERVICE_DESCRIPTORS:
		var owner := String(descriptor.get("slot", ""))
		for raw_dependency_spec in Array(descriptor.get("dependencies", [])):
			var dependency_spec := Dictionary(raw_dependency_spec)
			wiring_specs.append({
				"owner": owner,
				"dependency": String(dependency_spec.get("dependency", "")),
				"source": String(dependency_spec.get("source", "")),
			})
	return wiring_specs
