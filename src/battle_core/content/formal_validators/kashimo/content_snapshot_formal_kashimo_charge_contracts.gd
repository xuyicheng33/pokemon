extends RefCounted
class_name ContentSnapshotFormalKashimoChargeContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")

var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_validate_apply_charge(
		validator,
		content_index,
		errors,
		"formal[kashimo_hajime].apply_negative_charge",
		"kashimo_apply_negative_charge",
		"target",
		"on_hit",
		"kashimo_negative_charge_mark"
	)
	_validate_apply_charge(
		validator,
		content_index,
		errors,
		"formal[kashimo_hajime].apply_positive_charge",
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
		"formal[kashimo_hajime].consume_positive_charge",
		"kashimo_consume_positive_charges",
		"self",
		"kashimo_positive_charge_mark"
	)
	_validate_consume_charge(
		validator,
		content_index,
		errors,
		"formal[kashimo_hajime].consume_negative_charge",
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
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": label,
		"effect_id": effect_id,
		"fields": {
			"scope": expected_scope,
			"trigger_names": PackedStringArray([expected_trigger_name]),
		},
	}])
	var payload = validator._extract_single_payload(errors, label, effect_id, effect_definition, ApplyEffectPayloadScript, "apply_effect")
	validator._expect_payload_shape(
		errors,
		"%s payload" % label,
		payload,
		{"effect_definition_id": expected_mark_effect_id}
	)

func _validate_negative_charge_mark(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo_hajime].negative_charge_mark"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_negative_charge_mark")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": label,
		"effect_id": "kashimo_negative_charge_mark",
		"fields": {
			"scope": "self",
			"duration_mode": "turns",
			"duration": 4,
			"decrement_on": "turn_end",
			"stacking": "stack",
			"max_stacks": 3,
			"persists_on_switch": false,
			"trigger_names": PackedStringArray(["turn_end"]),
		},
	}])
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
	var label := "formal[kashimo_hajime].positive_charge_mark"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_positive_charge_mark")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": label,
		"effect_id": "kashimo_positive_charge_mark",
		"fields": {
			"scope": "self",
			"duration_mode": "turns",
			"duration": 4,
			"decrement_on": "turn_end",
			"stacking": "stack",
			"max_stacks": 3,
			"persists_on_switch": false,
			"trigger_names": PackedStringArray(["turn_start"]),
		},
	}])
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
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": label,
		"effect_id": effect_id,
		"fields": {
			"scope": expected_scope,
			"trigger_names": PackedStringArray(["on_hit"]),
		},
	}])
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
