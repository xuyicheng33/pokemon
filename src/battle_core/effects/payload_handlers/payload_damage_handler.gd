extends RefCounted
class_name PayloadDamageHandler

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")

var last_invalid_battle_code: Variant = null
var payload_damage_runtime_service

func invalid_battle_code() -> Variant:
	return last_invalid_battle_code

func resolve_missing_dependency() -> String:
	if payload_damage_runtime_service == null:
		return "payload_damage_runtime_service"
	if payload_damage_runtime_service.has_method("resolve_missing_dependency"):
		var missing_dependency := str(payload_damage_runtime_service.resolve_missing_dependency())
		if not missing_dependency.is_empty():
			return "payload_damage_runtime_service.%s" % missing_dependency
	return ""

func execute(payload, effect_definition, effect_event, battle_state, content_index) -> void:
	last_invalid_battle_code = null
	if not payload is DamagePayloadScript:
		return
	payload_damage_runtime_service.apply_damage_payload(payload, effect_definition, effect_event, battle_state, content_index)
