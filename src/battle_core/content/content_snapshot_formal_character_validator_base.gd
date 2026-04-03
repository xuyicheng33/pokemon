extends RefCounted
class_name ContentSnapshotFormalCharacterValidatorBase

func _require_unit(content_index, errors: Array, label: String, unit_id: String):
	var unit_definition = content_index.units.get(unit_id, null)
	if unit_definition == null:
		errors.append("%s missing unit: %s" % [label, unit_id])
	return unit_definition

func _require_skill(content_index, errors: Array, label: String, skill_id: String):
	var skill_definition = content_index.skills.get(skill_id, null)
	if skill_definition == null:
		errors.append("%s missing skill: %s" % [label, skill_id])
	return skill_definition

func _require_effect(content_index, errors: Array, label: String, effect_id: String):
	var effect_definition = content_index.effects.get(effect_id, null)
	if effect_definition == null:
		errors.append("%s missing effect: %s" % [label, effect_id])
	return effect_definition

func _require_field(content_index, errors: Array, label: String, field_id: String):
	var field_definition = content_index.fields.get(field_id, null)
	if field_definition == null:
		errors.append("%s missing field: %s" % [label, field_id])
	return field_definition

func _require_passive_skill(content_index, errors: Array, label: String, passive_skill_id: String):
	var passive_skill_definition = content_index.passive_skills.get(passive_skill_id, null)
	if passive_skill_definition == null:
		errors.append("%s missing passive_skill: %s" % [label, passive_skill_id])
	return passive_skill_definition

func _extract_single_payload(
	errors: Array,
	label: String,
	effect_id: String,
	effect_definition,
	payload_script,
	payload_name: String
):
	var matched_payloads: Array = []
	for payload in effect_definition.payloads:
		if payload != null and payload.get_script() == payload_script:
			matched_payloads.append(payload)
	if matched_payloads.size() != 1:
		errors.append("%s effect[%s] must define exactly one %s payload, got %d" % [
			label,
			effect_id,
			payload_name,
			matched_payloads.size(),
		])
		return null
	return matched_payloads[0]

func _expect_int(errors: Array, label: String, actual, expected: int) -> void:
	if int(actual) == expected:
		return
	errors.append("%s mismatch: expected %d got %d" % [label, expected, int(actual)])

func _expect_string(errors: Array, label: String, actual, expected: String) -> void:
	var actual_string := String(actual)
	if actual_string == expected:
		return
	errors.append("%s mismatch: expected %s got %s" % [label, expected, actual_string])

func _expect_bool(errors: Array, label: String, actual, expected: bool) -> void:
	if bool(actual) == expected:
		return
	errors.append("%s mismatch: expected %s got %s" % [label, var_to_str(expected), var_to_str(bool(actual))])

func _expect_packed_string_array(errors: Array, label: String, actual: PackedStringArray, expected: PackedStringArray) -> void:
	if actual == expected:
		return
	errors.append("%s mismatch: expected %s got %s" % [label, var_to_str(expected), var_to_str(actual)])

func _expect_payload_shape(errors: Array, label: String, payload, expected_fields: Dictionary) -> void:
	if payload == null:
		errors.append("%s payload missing" % label)
		return
	for raw_field_name in expected_fields.keys():
		var field_name := String(raw_field_name)
		var expected_value = expected_fields[raw_field_name]
		var actual_value = payload.get(field_name)
		if actual_value == expected_value:
			continue
		errors.append("%s.%s mismatch: expected %s got %s" % [
			label,
			field_name,
			var_to_str(expected_value),
			var_to_str(actual_value),
		])
