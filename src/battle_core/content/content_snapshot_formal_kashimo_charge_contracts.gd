extends RefCounted
class_name ContentSnapshotFormalKashimoChargeContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")

func validate(validator, content_index, errors: Array) -> void:
	_validate_apply_charge(
		validator,
		content_index,
		errors,
		"formal[kashimo].apply_negative_charge",
		"kashimo_apply_negative_charge",
		"target",
		"on_hit",
		"kashimo_negative_charge_mark"
	)
	_validate_apply_charge(
		validator,
		content_index,
		errors,
		"formal[kashimo].apply_positive_charge",
		"kashimo_apply_positive_charge",
		"self",
		"on_cast",
		"kashimo_positive_charge_mark"
	)
	_validate_negative_charge_mark(validator, content_index, errors)
	_validate_positive_charge_mark(validator, content_index, errors)
	_validate_consume_charge(
		validator,
		content_index,
		errors,
		"formal[kashimo].consume_positive_charge",
		"kashimo_consume_positive_charges",
		"self",
		"kashimo_positive_charge_mark"
	)
	_validate_consume_charge(
		validator,
		content_index,
		errors,
		"formal[kashimo].consume_negative_charge",
		"kashimo_consume_negative_charges",
		"target",
		"kashimo_negative_charge_mark"
	)

func _validate_apply_charge(
	validator,
	content_index,
	errors: Array,
	label: String,
	effect_id: String,
	expected_scope: String,
	expected_trigger_name: String,
	expected_mark_effect_id: String
) -> void:
	var effect_definition = validator._require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, expected_scope)
	validator._expect_packed_string_array(
		errors,
		"%s trigger_names" % label,
		effect_definition.trigger_names,
		PackedStringArray([expected_trigger_name])
	)
	var payload = validator._extract_single_payload(errors, label, effect_id, effect_definition, ApplyEffectPayloadScript, "apply_effect")
	validator._expect_payload_shape(
		errors,
		"%s payload" % label,
		payload,
		{"effect_definition_id": expected_mark_effect_id}
	)

func _validate_negative_charge_mark(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].negative_charge_mark"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_negative_charge_mark")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, "self")
	validator._expect_string(errors, "%s duration_mode" % label, effect_definition.duration_mode, "turns")
	validator._expect_int(errors, "%s duration" % label, effect_definition.duration, 4)
	validator._expect_string(errors, "%s decrement_on" % label, effect_definition.decrement_on, "turn_end")
	validator._expect_string(errors, "%s stacking" % label, effect_definition.stacking, "stack")
	validator._expect_int(errors, "%s max_stacks" % label, effect_definition.max_stacks, 3)
	validator._expect_bool(errors, "%s persists_on_switch" % label, effect_definition.persists_on_switch, false)
	validator._expect_packed_string_array(
		errors,
		"%s trigger_names" % label,
		effect_definition.trigger_names,
		PackedStringArray(["turn_end"])
	)
	var damage_payload = validator._extract_single_payload(
		errors,
		label,
		"kashimo_negative_charge_mark",
		effect_definition,
		DamagePayloadScript,
		"damage"
	)
	validator._expect_payload_shape(
		errors,
		"%s payload" % label,
		damage_payload,
		{"amount": 8, "use_formula": false, "combat_type_id": "thunder"}
	)

func _validate_positive_charge_mark(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].positive_charge_mark"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_positive_charge_mark")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, "self")
	validator._expect_string(errors, "%s duration_mode" % label, effect_definition.duration_mode, "turns")
	validator._expect_int(errors, "%s duration" % label, effect_definition.duration, 4)
	validator._expect_string(errors, "%s decrement_on" % label, effect_definition.decrement_on, "turn_end")
	validator._expect_string(errors, "%s stacking" % label, effect_definition.stacking, "stack")
	validator._expect_int(errors, "%s max_stacks" % label, effect_definition.max_stacks, 3)
	validator._expect_bool(errors, "%s persists_on_switch" % label, effect_definition.persists_on_switch, false)
	validator._expect_packed_string_array(
		errors,
		"%s trigger_names" % label,
		effect_definition.trigger_names,
		PackedStringArray(["turn_start"])
	)
	var resource_payload = validator._extract_single_payload(
		errors,
		label,
		"kashimo_positive_charge_mark",
		effect_definition,
		ResourceModPayloadScript,
		"resource_mod"
	)
	validator._expect_payload_shape(
		errors,
		"%s payload" % label,
		resource_payload,
		{"resource_key": "mp", "amount": 5}
	)

func _validate_consume_charge(
	validator,
	content_index,
	errors: Array,
	label: String,
	effect_id: String,
	expected_scope: String,
	expected_mark_effect_id: String
) -> void:
	var effect_definition = validator._require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s scope" % label, effect_definition.scope, expected_scope)
	validator._expect_packed_string_array(
		errors,
		"%s trigger_names" % label,
		effect_definition.trigger_names,
		PackedStringArray(["on_hit"])
	)
	var payload = validator._extract_single_payload(
		errors,
		label,
		effect_id,
		effect_definition,
		RemoveEffectPayloadScript,
		"remove_effect"
	)
	validator._expect_payload_shape(
		errors,
		"%s payload" % label,
		payload,
		{"effect_definition_id": expected_mark_effect_id, "remove_mode": "all"}
	)
