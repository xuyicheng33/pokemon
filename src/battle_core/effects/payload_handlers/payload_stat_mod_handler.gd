extends RefCounted
class_name PayloadStatModHandler

const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var last_invalid_battle_code: Variant = null
var payload_stat_mod_runtime_service

func resolve_missing_dependency() -> String:
	if payload_stat_mod_runtime_service == null:
		return "payload_stat_mod_runtime_service"
	if payload_stat_mod_runtime_service.has_method("resolve_missing_dependency"):
		var missing_dependency := str(payload_stat_mod_runtime_service.resolve_missing_dependency())
		if not missing_dependency.is_empty():
			return "payload_stat_mod_runtime_service.%s" % missing_dependency
	return ""

func execute(payload, effect_definition, effect_event, battle_state, _content_index) -> void:
	last_invalid_battle_code = null
	if not payload is StatModPayloadScript:
		return
	payload_stat_mod_runtime_service.apply_stat_mod_payload(payload, effect_definition, effect_event, battle_state)
