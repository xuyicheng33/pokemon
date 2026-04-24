extends RefCounted
class_name PayloadValidatorRegistry

const DamagePayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/damage_payload_validator.gd")
const HealPayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/heal_payload_validator.gd")
const ResourceModPayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/resource_mod_payload_validator.gd")
const StatModPayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/stat_mod_payload_validator.gd")
const ApplyFieldPayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/apply_field_payload_validator.gd")
const ApplyEffectPayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/apply_effect_payload_validator.gd")
const RemoveEffectPayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/remove_effect_payload_validator.gd")
const RuleModPayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/rule_mod_payload_validator.gd")
const ForcedReplacePayloadValidatorScript := preload("res://src/battle_core/content/payload_validators/forced_replace_payload_validator.gd")

const VALIDATOR_DESCRIPTORS := [
	{"validator_key": "damage", "script": DamagePayloadValidatorScript},
	{"validator_key": "heal", "script": HealPayloadValidatorScript},
	{"validator_key": "resource_mod", "script": ResourceModPayloadValidatorScript},
	{"validator_key": "stat_mod", "script": StatModPayloadValidatorScript},
	{"validator_key": "apply_field", "script": ApplyFieldPayloadValidatorScript},
	{"validator_key": "apply_effect", "script": ApplyEffectPayloadValidatorScript},
	{"validator_key": "remove_effect", "script": RemoveEffectPayloadValidatorScript},
	{"validator_key": "rule_mod", "script": RuleModPayloadValidatorScript},
	{"validator_key": "forced_replace", "script": ForcedReplacePayloadValidatorScript},
]

static func descriptors() -> Array:
	return VALIDATOR_DESCRIPTORS.duplicate(true)

static func registered_validator_keys() -> PackedStringArray:
	var validator_keys := PackedStringArray()
	for descriptor in VALIDATOR_DESCRIPTORS:
		var validator_key := String(descriptor.get("validator_key", "")).strip_edges()
		if validator_key.is_empty():
			continue
		validator_keys.append(validator_key)
	return validator_keys

static func validator_script_for_key(validator_key: String) -> Variant:
	return descriptor_for_key(validator_key).get("script", null)

static func validator_script_path_for_key(validator_key: String) -> String:
	var script = validator_script_for_key(validator_key)
	if script == null or script.resource_path == null:
		return ""
	return String(script.resource_path)

static func descriptor_for_key(validator_key: String) -> Dictionary:
	var normalized_key := validator_key.strip_edges()
	for descriptor in VALIDATOR_DESCRIPTORS:
		if String(descriptor.get("validator_key", "")).strip_edges() == normalized_key:
			return descriptor.duplicate(true)
	return {}
