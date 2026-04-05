extends RefCounted
class_name PayloadHandlerRegistry

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")

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
	var payload_script = payload.get_script()
	for spec in _handler_specs():
		if payload_script == spec["script"]:
			return get(String(spec["slot"]))
	return null

func registered_payload_script_paths() -> PackedStringArray:
	var script_paths := PackedStringArray()
	for spec in _handler_specs():
		var payload_script = spec["script"]
		if payload_script != null and payload_script.resource_path != null:
			script_paths.append(String(payload_script.resource_path))
	return script_paths

func registered_handler_slots() -> PackedStringArray:
	var slots := PackedStringArray()
	for spec in _handler_specs():
		slots.append(String(spec["slot"]))
	return slots

func _handler_specs() -> Array:
	return [
		{"script": DamagePayloadScript, "slot": "payload_damage_handler"},
		{"script": HealPayloadScript, "slot": "payload_heal_handler"},
		{"script": ResourceModPayloadScript, "slot": "payload_resource_mod_handler"},
		{"script": StatModPayloadScript, "slot": "payload_stat_mod_handler"},
		{"script": ApplyFieldPayloadScript, "slot": "payload_apply_field_handler"},
		{"script": ApplyEffectPayloadScript, "slot": "payload_apply_effect_handler"},
		{"script": RemoveEffectPayloadScript, "slot": "payload_remove_effect_handler"},
		{"script": RuleModPayloadScript, "slot": "payload_rule_mod_handler"},
		{"script": ForcedReplacePayloadScript, "slot": "payload_forced_replace_handler"},
	]
