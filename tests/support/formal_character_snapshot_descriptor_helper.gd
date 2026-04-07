extends RefCounted
class_name FormalCharacterSnapshotDescriptorHelper

const UNIT_FIELD_ORDER: Array[String] = [
	"display_name",
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
	"combat_type_ids",
	"skill_ids",
	"candidate_skill_ids",
	"ultimate_skill_id",
	"passive_skill_id",
	"passive_item_id",
]

const SKILL_FIELD_ORDER: Array[String] = [
	"display_name",
	"damage_kind",
	"power",
	"accuracy",
	"mp_cost",
	"priority",
	"combat_type_id",
	"targeting",
	"power_bonus_source",
	"power_bonus_self_effect_ids",
	"power_bonus_target_effect_ids",
	"power_bonus_per_stack",
	"execute_target_hp_ratio_lte",
	"execute_required_total_stacks",
	"execute_self_effect_ids",
	"execute_target_effect_ids",
	"is_domain_skill",
	"once_per_battle",
	"effects_on_cast_ids",
	"effects_on_hit_ids",
	"effects_on_miss_ids",
	"effects_on_kill_ids",
]

const PASSIVE_FIELD_ORDER: Array[String] = [
	"display_name",
	"trigger_names",
	"effect_ids",
]

const EFFECT_FIELD_ORDER: Array[String] = [
	"display_name",
	"scope",
	"duration_mode",
	"duration",
	"decrement_on",
	"stacking",
	"max_stacks",
	"trigger_names",
	"on_expire_effect_ids",
	"required_target_effects",
	"required_incoming_command_types",
	"required_incoming_combat_type_ids",
	"persists_on_switch",
	"required_target_same_owner",
]

const FIELD_FIELD_ORDER: Array[String] = [
	"display_name",
	"field_kind",
	"effect_ids",
	"on_expire_effect_ids",
	"on_break_effect_ids",
	"creator_accuracy_override",
]

func append_unit_checks(checks: Array[Dictionary], unit_definition, descriptor: Dictionary) -> void:
	_append_descriptor_checks(checks, unit_definition, descriptor, UNIT_FIELD_ORDER)

func append_skill_checks(checks: Array[Dictionary], skill_definition, descriptor: Dictionary) -> void:
	_append_descriptor_checks(checks, skill_definition, descriptor, SKILL_FIELD_ORDER)

func append_passive_checks(checks: Array[Dictionary], passive_skill_definition, descriptor: Dictionary) -> void:
	_append_descriptor_checks(checks, passive_skill_definition, descriptor, PASSIVE_FIELD_ORDER)

func append_effect_checks(checks: Array[Dictionary], effect_definition, descriptor: Dictionary) -> void:
	_append_descriptor_checks(checks, effect_definition, descriptor, EFFECT_FIELD_ORDER)

func append_field_checks(checks: Array[Dictionary], field_definition, descriptor: Dictionary) -> void:
	_append_descriptor_checks(checks, field_definition, descriptor, FIELD_FIELD_ORDER)

func build_descriptor_checks(content_map: Dictionary, descriptors: Array, id_key: String) -> Dictionary:
	var checks: Array[Dictionary] = []
	var missing_ids: Array[String] = []
	var field_order := _field_order_for_id_key(id_key)
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			continue
		var descriptor: Dictionary = raw_descriptor
		var definition_id := String(descriptor.get(id_key, "")).strip_edges()
		if definition_id.is_empty():
			missing_ids.append("<missing %s>" % id_key)
			continue
		var definition = content_map.get(definition_id, null)
		if definition == null:
			missing_ids.append(definition_id)
			continue
		_append_descriptor_checks(checks, definition, descriptor, field_order)
	return {
		"checks": checks,
		"missing_ids": missing_ids,
	}

func _append_descriptor_checks(checks: Array[Dictionary], subject, descriptor: Dictionary, field_order: Array[String]) -> void:
	var label_prefix := String(descriptor.get("snapshot_label", descriptor.get("label", "")))
	var expected_fields: Dictionary = descriptor.get("fields", {})
	for field_name in _ordered_field_names(expected_fields, field_order):
		var expected_value = expected_fields.get(field_name)
		checks.append({
			"label": "%s %s" % [label_prefix, field_name],
			"actual": _normalize_actual_value(subject.get(field_name), expected_value),
			"expected": expected_value,
		})

func _ordered_field_names(expected_fields: Dictionary, field_order: Array[String]) -> Array[String]:
	var ordered_fields: Array[String] = []
	var seen_lookup: Dictionary = {}
	for field_name in field_order:
		if expected_fields.has(field_name):
			ordered_fields.append(field_name)
			seen_lookup[field_name] = true
	var remaining_fields: Array[String] = []
	for raw_field_name in expected_fields.keys():
		var field_name := String(raw_field_name)
		if seen_lookup.has(field_name):
			continue
		remaining_fields.append(field_name)
	remaining_fields.sort()
	ordered_fields.append_array(remaining_fields)
	return ordered_fields

func _field_order_for_id_key(id_key: String) -> Array[String]:
	match id_key:
		"unit_id":
			return UNIT_FIELD_ORDER
		"skill_id":
			return SKILL_FIELD_ORDER
		"passive_skill_id":
			return PASSIVE_FIELD_ORDER
		"effect_id":
			return EFFECT_FIELD_ORDER
		"field_id":
			return FIELD_FIELD_ORDER
	return []

func _normalize_actual_value(actual, expected):
	if expected is bool:
		return bool(actual)
	if expected is int:
		return int(actual)
	if expected is float:
		return float(actual)
	if expected is String:
		return String(actual)
	if expected is PackedStringArray:
		if actual is PackedStringArray:
			return actual
		if actual is Array:
			return PackedStringArray(actual)
		return PackedStringArray()
	if expected is PackedInt32Array:
		if actual is PackedInt32Array:
			return actual
		if actual is Array:
			return PackedInt32Array(actual)
		return PackedInt32Array()
	if expected is PackedFloat32Array:
		if actual is PackedFloat32Array:
			return actual
		if actual is Array:
			return PackedFloat32Array(actual)
		return PackedFloat32Array()
	return actual
