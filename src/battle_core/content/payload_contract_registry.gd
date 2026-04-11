extends RefCounted
class_name PayloadContractRegistry

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")

const PAYLOAD_DESCRIPTORS := [
	{
		"script": DamagePayloadScript,
		"handler_slot": "payload_damage_handler",
		"validator_key": "damage",
		"handler_dependencies": [
			{"dependency": "payload_damage_runtime_service", "source": "payload_damage_runtime_service"},
		],
	},
	{
		"script": HealPayloadScript,
		"handler_slot": "payload_heal_handler",
		"validator_key": "heal",
		"handler_dependencies": [
			{"dependency": "payload_resource_runtime_service", "source": "payload_resource_runtime_service"},
		],
	},
	{
		"script": ResourceModPayloadScript,
		"handler_slot": "payload_resource_mod_handler",
		"validator_key": "resource_mod",
		"handler_dependencies": [
			{"dependency": "payload_resource_runtime_service", "source": "payload_resource_runtime_service"},
		],
	},
	{
		"script": StatModPayloadScript,
		"handler_slot": "payload_stat_mod_handler",
		"validator_key": "stat_mod",
		"handler_dependencies": [
			{"dependency": "payload_stat_mod_runtime_service", "source": "payload_stat_mod_runtime_service"},
		],
	},
	{
		"script": ApplyFieldPayloadScript,
		"handler_slot": "payload_apply_field_handler",
		"validator_key": "apply_field",
		"handler_dependencies": [
			{"dependency": "field_apply_service", "source": "field_apply_service"},
		],
	},
	{
		"script": ApplyEffectPayloadScript,
		"handler_slot": "payload_apply_effect_handler",
		"validator_key": "apply_effect",
		"handler_dependencies": [
			{"dependency": "battle_logger", "source": "battle_logger"},
			{"dependency": "log_event_builder", "source": "log_event_builder"},
			{"dependency": "effect_instance_service", "source": "effect_instance_service"},
			{"dependency": "target_helper", "source": "payload_unit_target_helper"},
			{"dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
		],
	},
	{
		"script": RemoveEffectPayloadScript,
		"handler_slot": "payload_remove_effect_handler",
		"validator_key": "remove_effect",
		"handler_dependencies": [
			{"dependency": "battle_logger", "source": "battle_logger"},
			{"dependency": "log_event_builder", "source": "log_event_builder"},
			{"dependency": "effect_instance_service", "source": "effect_instance_service"},
			{"dependency": "target_helper", "source": "payload_unit_target_helper"},
			{"dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
		],
	},
	{
		"script": RuleModPayloadScript,
		"handler_slot": "payload_rule_mod_handler",
		"validator_key": "rule_mod",
		"handler_dependencies": [
			{"dependency": "battle_logger", "source": "battle_logger"},
			{"dependency": "log_event_builder", "source": "log_event_builder"},
			{"dependency": "rule_mod_service", "source": "rule_mod_service"},
			{"dependency": "rule_mod_value_resolver", "source": "rule_mod_value_resolver"},
			{"dependency": "target_helper", "source": "payload_unit_target_helper"},
			{"dependency": "effect_event_helper", "source": "payload_effect_event_helper"},
		],
	},
	{
		"script": ForcedReplacePayloadScript,
		"handler_slot": "payload_forced_replace_handler",
		"validator_key": "forced_replace",
		"handler_dependencies": [
			{"dependency": "replacement_service", "source": "replacement_service"},
			{"dependency": "target_helper", "source": "payload_unit_target_helper"},
		],
	},
]

static func descriptors() -> Array:
	return PAYLOAD_DESCRIPTORS.duplicate(true)

static func registered_payload_script_paths() -> PackedStringArray:
	var script_paths := PackedStringArray()
	for descriptor in PAYLOAD_DESCRIPTORS:
		var payload_script = descriptor.get("script", null)
		if payload_script != null and payload_script.resource_path != null:
			script_paths.append(String(payload_script.resource_path))
	return script_paths

static func registered_handler_slots() -> PackedStringArray:
	var slots := PackedStringArray()
	for descriptor in PAYLOAD_DESCRIPTORS:
		slots.append(String(descriptor.get("handler_slot", "")))
	return slots

static func registered_validator_keys() -> PackedStringArray:
	var validator_keys := PackedStringArray()
	var seen_validator_keys: Dictionary = {}
	for descriptor in PAYLOAD_DESCRIPTORS:
		var validator_key := String(descriptor.get("validator_key", "")).strip_edges()
		if validator_key.is_empty() or seen_validator_keys.has(validator_key):
			continue
		seen_validator_keys[validator_key] = true
		validator_keys.append(validator_key)
	return validator_keys

static func registry_wiring_specs() -> Array:
	var wiring_specs: Array = []
	for handler_slot in registered_handler_slots():
		wiring_specs.append({
			"owner": "payload_handler_registry",
			"dependency": handler_slot,
			"source": handler_slot,
		})
	return wiring_specs

static func handler_wiring_specs() -> Array:
	var wiring_specs: Array = []
	for descriptor in PAYLOAD_DESCRIPTORS:
		var handler_slot := String(descriptor.get("handler_slot", ""))
		for raw_dependency_spec in Array(descriptor.get("handler_dependencies", [])):
			var dependency_spec := Dictionary(raw_dependency_spec)
			wiring_specs.append({
				"owner": handler_slot,
				"dependency": String(dependency_spec.get("dependency", "")),
				"source": String(dependency_spec.get("source", "")),
			})
	return wiring_specs

static func handler_slot_for_payload(payload) -> String:
	var descriptor := descriptor_for_payload(payload)
	return String(descriptor.get("handler_slot", ""))

static func validator_key_for_payload(payload) -> String:
	var descriptor := descriptor_for_payload(payload)
	return String(descriptor.get("validator_key", ""))

static func descriptor_for_payload(payload) -> Dictionary:
	if payload == null:
		return {}
	var payload_script = payload.get_script()
	for descriptor in PAYLOAD_DESCRIPTORS:
		if payload_script == descriptor.get("script", null):
			return descriptor
	return {}
