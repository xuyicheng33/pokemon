extends RefCounted
class_name ContentSnapshotFormalCharacterUnitSkillContractHelper

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

func validate_unit_contract_descriptor(validator, content_index, errors: Array, descriptor: Dictionary) -> Variant:
	var label := String(descriptor.get("label", "")).strip_edges()
	var unit_id := String(descriptor.get("unit_id", "")).strip_edges()
	var expected_fields: Dictionary = descriptor.get("fields", {})
	if label.is_empty() or unit_id.is_empty():
		errors.append("formal unit contract descriptor missing label or unit_id")
		return null
	return validate_unit_contract(validator, content_index, errors, label, unit_id, expected_fields)

func validate_skill_contracts(validator, content_index, errors: Array, descriptors: Array) -> void:
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			errors.append("formal skill contract descriptor must be Dictionary")
			continue
		_validate_skill_contract(validator, content_index, errors, raw_descriptor)

func validate_passive_skill_contracts(validator, content_index, errors: Array, descriptors: Array) -> void:
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			errors.append("formal passive contract descriptor must be Dictionary")
			continue
		_validate_passive_skill_contract(validator, content_index, errors, raw_descriptor)

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
	for field_name in ["power", "accuracy", "mp_cost", "priority", "power_bonus_per_stack", "execute_required_total_stacks"]:
		if expected_fields.has(field_name):
			validator._expect_int(errors, "%s %s" % [label, field_name], skill_definition.get(field_name), int(expected_fields.get(field_name, 0)))
	for field_name in ["execute_target_hp_ratio_lte"]:
		if expected_fields.has(field_name):
			validator._expect_float(errors, "%s %s" % [label, field_name], skill_definition.get(field_name), float(expected_fields.get(field_name, 0.0)))
	for field_name in ["is_domain_skill", "once_per_battle"]:
		if expected_fields.has(field_name):
			validator._expect_bool(errors, "%s %s" % [label, field_name], skill_definition.get(field_name), bool(expected_fields.get(field_name, false)))
	for field_name in [
		"effects_on_cast_ids",
		"effects_on_hit_ids",
		"effects_on_miss_ids",
		"effects_on_kill_ids",
		"power_bonus_self_effect_ids",
		"power_bonus_target_effect_ids",
		"execute_self_effect_ids",
		"execute_target_effect_ids",
	]:
		if expected_fields.has(field_name):
			validator._expect_packed_string_array(
				errors,
				"%s %s" % [label, field_name],
				skill_definition.get(field_name),
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
