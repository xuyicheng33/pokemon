extends RefCounted
class_name ContentSnapshotFormalCharacterEffectFieldContractHelper

func validate_effect_contracts(validator, content_index, errors: Array, descriptors: Array) -> void:
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			errors.append("formal effect contract descriptor must be Dictionary")
			continue
		_validate_effect_contract(validator, content_index, errors, raw_descriptor)

func validate_field_contracts(validator, content_index, errors: Array, descriptors: Array) -> void:
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			errors.append("formal field contract descriptor must be Dictionary")
			continue
		_validate_field_contract(validator, content_index, errors, raw_descriptor)

func expect_single_payload_shape(
	validator,
	errors: Array,
	label: String,
	effect_id: String,
	effect_definition,
	payload_script,
	payload_name: String,
	expected_fields: Dictionary
) -> Variant:
	var payload = validator._extract_single_payload(
		errors,
		label,
		effect_id,
		effect_definition,
		payload_script,
		payload_name
	)
	validator._expect_payload_shape(errors, "%s %s" % [label, payload_name], payload, expected_fields)
	return payload

func _validate_effect_contract(validator, content_index, errors: Array, descriptor: Dictionary) -> void:
	var label := String(descriptor.get("label", "")).strip_edges()
	var effect_id := String(descriptor.get("effect_id", "")).strip_edges()
	var expected_fields: Dictionary = descriptor.get("fields", {})
	if label.is_empty() or effect_id.is_empty():
		errors.append("formal effect contract descriptor missing label or effect_id")
		return
	var effect_definition = validator._require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	for field_name in ["display_name", "scope", "duration_mode", "decrement_on", "stacking"]:
		if expected_fields.has(field_name):
			validator._expect_string(errors, "%s %s" % [label, field_name], effect_definition.get(field_name), String(expected_fields.get(field_name, "")))
	for field_name in ["duration", "max_stacks"]:
		if expected_fields.has(field_name):
			validator._expect_int(errors, "%s %s" % [label, field_name], effect_definition.get(field_name), int(expected_fields.get(field_name, 0)))
	for field_name in ["persists_on_switch", "required_target_same_owner"]:
		if expected_fields.has(field_name):
			validator._expect_bool(errors, "%s %s" % [label, field_name], effect_definition.get(field_name), bool(expected_fields.get(field_name, false)))
	for field_name in [
		"trigger_names",
		"on_expire_effect_ids",
		"required_target_effects",
		"required_incoming_command_types",
		"required_incoming_combat_type_ids",
	]:
		if expected_fields.has(field_name):
			validator._expect_packed_string_array(
				errors,
				"%s %s" % [label, field_name],
				effect_definition.get(field_name),
				expected_fields.get(field_name, PackedStringArray())
			)

func _validate_field_contract(validator, content_index, errors: Array, descriptor: Dictionary) -> void:
	var label := String(descriptor.get("label", "")).strip_edges()
	var field_id := String(descriptor.get("field_id", "")).strip_edges()
	var expected_fields: Dictionary = descriptor.get("fields", {})
	if label.is_empty() or field_id.is_empty():
		errors.append("formal field contract descriptor missing label or field_id")
		return
	var field_definition = validator._require_field(content_index, errors, label, field_id)
	if field_definition == null:
		return
	for field_name in ["display_name", "field_kind"]:
		if expected_fields.has(field_name):
			validator._expect_string(errors, "%s %s" % [label, field_name], field_definition.get(field_name), String(expected_fields.get(field_name, "")))
	for field_name in ["creator_accuracy_override"]:
		if expected_fields.has(field_name):
			validator._expect_int(errors, "%s %s" % [label, field_name], field_definition.get(field_name), int(expected_fields.get(field_name, 0)))
	for field_name in ["effect_ids", "on_expire_effect_ids", "on_break_effect_ids"]:
		if expected_fields.has(field_name):
			validator._expect_packed_string_array(
				errors,
				"%s %s" % [label, field_name],
				field_definition.get(field_name),
				expected_fields.get(field_name, PackedStringArray())
			)
