extends RefCounted
class_name PlayerDefaultPolicy

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func decide(side_id: String, public_snapshot: Dictionary, legal_actions) -> Dictionary:
	if legal_actions == null:
		return _fail("PlayerDefaultPolicy.decide requires non-null legal_actions for side %s" % str(side_id))
	var forced_command_type := str(_read_property(legal_actions, "forced_command_type", "")).strip_edges()
	if not forced_command_type.is_empty():
		return ResultEnvelopeHelperScript.ok({
			"command_type": forced_command_type,
			"command_source": "policy",
		})
	var legal_ultimate_ids := _to_string_array(_read_property(legal_actions, "legal_ultimate_ids", []))
	if not legal_ultimate_ids.is_empty():
		return ResultEnvelopeHelperScript.ok({
			"command_type": CommandTypesScript.ULTIMATE,
			"skill_id": legal_ultimate_ids[0],
			"command_source": "policy",
		})
	var legal_skill_ids := _to_string_array(_read_property(legal_actions, "legal_skill_ids", []))
	var counter_skill_id := _resolve_counter_skill_id(public_snapshot, side_id, legal_skill_ids)
	if not counter_skill_id.is_empty():
		return ResultEnvelopeHelperScript.ok({
			"command_type": CommandTypesScript.SKILL,
			"skill_id": counter_skill_id,
			"command_source": "policy",
		})
	if not legal_skill_ids.is_empty():
		return ResultEnvelopeHelperScript.ok({
			"command_type": CommandTypesScript.SKILL,
			"skill_id": legal_skill_ids[0],
			"command_source": "policy",
		})
	var legal_switch_target_public_ids := _to_string_array(_read_property(legal_actions, "legal_switch_target_public_ids", []))
	if not legal_switch_target_public_ids.is_empty():
		return ResultEnvelopeHelperScript.ok({
			"command_type": CommandTypesScript.SWITCH,
			"target_public_id": legal_switch_target_public_ids[0],
			"command_source": "policy",
		})
	if bool(_read_property(legal_actions, "wait_allowed", false)):
		return ResultEnvelopeHelperScript.ok({
			"command_type": CommandTypesScript.WAIT,
			"command_source": "policy",
		})
	return _fail("PlayerDefaultPolicy.decide found no legal action for side %s" % str(side_id))

func _resolve_counter_skill_id(public_snapshot: Dictionary, side_id: String, legal_skill_ids: Array) -> String:
	if legal_skill_ids.is_empty():
		return ""
	var active_unit := _resolve_active_unit(public_snapshot, side_id)
	if active_unit.is_empty():
		return ""
	var effects = active_unit.get("effect_instances", [])
	if not (effects is Array):
		return ""
	for effect_summary in effects:
		if not (effect_summary is Dictionary):
			continue
		var definition_id := str(effect_summary.get("effect_definition_id", "")).strip_edges()
		if definition_id.is_empty():
			continue
		if not (definition_id.find("counter") >= 0 or definition_id.find("reflect") >= 0):
			continue
		for skill_id in legal_skill_ids:
			var normalized := str(skill_id).strip_edges()
			if normalized.is_empty():
				continue
			if normalized.find("counter") >= 0 or normalized.find("reflect") >= 0:
				return normalized
	return ""

func _resolve_active_unit(public_snapshot: Dictionary, side_id: String) -> Dictionary:
	if public_snapshot == null or public_snapshot.is_empty():
		return {}
	var sides = public_snapshot.get("sides", [])
	if not (sides is Array):
		return {}
	var normalized_side_id := str(side_id).strip_edges()
	for side_model in sides:
		if not (side_model is Dictionary):
			continue
		if str(side_model.get("side_id", "")).strip_edges() != normalized_side_id:
			continue
		var active_public_id := str(side_model.get("active_public_id", "")).strip_edges()
		if active_public_id.is_empty():
			return {}
		var team_units = side_model.get("team_units", [])
		if not (team_units is Array):
			return {}
		for unit_model in team_units:
			if not (unit_model is Dictionary):
				continue
			if str(unit_model.get("public_id", "")).strip_edges() == active_public_id:
				return unit_model
		return {}
	return {}

func _read_property(value, property_name: String, default_value = null) -> Variant:
	if value == null:
		return default_value
	if value is Dictionary:
		return value.get(property_name, default_value)
	if typeof(value) != TYPE_OBJECT:
		return default_value
	for property_info in value.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return value.get(property_name)
	return default_value

func _to_string_array(raw_value) -> Array:
	var result: Array = []
	if raw_value == null:
		return result
	if raw_value is PackedStringArray:
		for raw_item in raw_value:
			result.append(str(raw_item).strip_edges())
		return result
	if raw_value is Array:
		for raw_item in raw_value:
			result.append(str(raw_item).strip_edges())
	return result

func _fail(message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, message)
