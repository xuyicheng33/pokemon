extends RefCounted
class_name ContentSnapshotFormalCharacterContractHelper

func validate_unit_contract(
	validator,
	content_index,
	errors: Array,
	label: String,
	unit_id: String,
	expected_fields: Dictionary
) -> Variant:
	var unit_definition = validator._require_unit(content_index, errors, label, unit_id)
	if unit_definition == null:
		return null
	if expected_fields.has("display_name"):
		validator._expect_string(errors, "%s display_name" % label, unit_definition.display_name, String(expected_fields.get("display_name", "")))
	for field_name in [
		"base_hp",
		"base_attack",
		"base_defense",
		"base_sp_attack",
		"base_sp_defense",
		"base_speed",
		"max_mp",
		"init_mp",
		"regen_per_turn",
		"ultimate_points_required",
		"ultimate_points_cap",
		"ultimate_point_gain_on_regular_skill_cast",
	]:
		if expected_fields.has(field_name):
			validator._expect_int(errors, "%s %s" % [label, field_name], unit_definition.get(field_name), int(expected_fields.get(field_name, 0)))
	for field_name in ["combat_type_ids", "skill_ids", "candidate_skill_ids"]:
		if expected_fields.has(field_name):
			validator._expect_packed_string_array(
				errors,
				"%s %s" % [label, field_name],
				unit_definition.get(field_name),
				expected_fields.get(field_name, PackedStringArray())
			)
	for field_name in ["ultimate_skill_id", "passive_skill_id", "passive_item_id"]:
		if expected_fields.has(field_name):
			validator._expect_string(errors, "%s %s" % [label, field_name], unit_definition.get(field_name), String(expected_fields.get(field_name, "")))
	return unit_definition

func validate_skill_contracts(validator, content_index, errors: Array, descriptors: Array) -> void:
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			errors.append("formal skill contract descriptor must be Dictionary")
			continue
		_validate_skill_contract(validator, content_index, errors, raw_descriptor)

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

func validate_passive_skill_contracts(validator, content_index, errors: Array, descriptors: Array) -> void:
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			errors.append("formal passive contract descriptor must be Dictionary")
			continue
		_validate_passive_skill_contract(validator, content_index, errors, raw_descriptor)

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

func _validate_skill_contract(validator, content_index, errors: Array, descriptor: Dictionary) -> void:
	var label := String(descriptor.get("label", "")).strip_edges()
	var skill_id := String(descriptor.get("skill_id", "")).strip_edges()
	var expected_fields: Dictionary = descriptor.get("fields", {})
	if label.is_empty() or skill_id.is_empty():
		errors.append("formal skill contract descriptor missing label or skill_id")
		return
	var skill_definition = validator._require_skill(content_index, errors, label, skill_id)
	if skill_definition == null:
		return
	for field_name in ["display_name", "damage_kind", "combat_type_id", "targeting", "power_bonus_source"]:
		if expected_fields.has(field_name):
			validator._expect_string(errors, "%s %s" % [label, field_name], skill_definition.get(field_name), String(expected_fields.get(field_name, "")))
	for field_name in ["power", "accuracy", "mp_cost", "priority"]:
		if expected_fields.has(field_name):
			validator._expect_int(errors, "%s %s" % [label, field_name], skill_definition.get(field_name), int(expected_fields.get(field_name, 0)))
	for field_name in ["is_domain_skill", "once_per_battle"]:
		if expected_fields.has(field_name):
			validator._expect_bool(errors, "%s %s" % [label, field_name], skill_definition.get(field_name), bool(expected_fields.get(field_name, false)))
	for field_name in ["effects_on_cast_ids", "effects_on_hit_ids", "effects_on_miss_ids", "effects_on_kill_ids"]:
		if expected_fields.has(field_name):
			validator._expect_packed_string_array(
				errors,
				"%s %s" % [label, field_name],
				skill_definition.get(field_name),
				expected_fields.get(field_name, PackedStringArray())
			)

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

func _validate_passive_skill_contract(validator, content_index, errors: Array, descriptor: Dictionary) -> void:
	var label := String(descriptor.get("label", "")).strip_edges()
	var passive_skill_id := String(descriptor.get("passive_skill_id", "")).strip_edges()
	var expected_fields: Dictionary = descriptor.get("fields", {})
	if label.is_empty() or passive_skill_id.is_empty():
		errors.append("formal passive contract descriptor missing label or passive_skill_id")
		return
	var passive_skill_definition = validator._require_passive_skill(content_index, errors, label, passive_skill_id)
	if passive_skill_definition == null:
		return
	if expected_fields.has("display_name"):
		validator._expect_string(errors, "%s display_name" % label, passive_skill_definition.display_name, String(expected_fields.get("display_name", "")))
	for field_name in ["trigger_names", "effect_ids"]:
		if expected_fields.has(field_name):
			validator._expect_packed_string_array(
				errors,
				"%s %s" % [label, field_name],
				passive_skill_definition.get(field_name),
				expected_fields.get(field_name, PackedStringArray())
			)
