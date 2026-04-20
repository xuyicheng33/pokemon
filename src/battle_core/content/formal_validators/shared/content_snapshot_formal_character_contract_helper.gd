extends RefCounted
class_name ContentSnapshotFormalCharacterContractHelper

const EffectFieldContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_effect_field_contract_helper.gd")
const UnitSkillContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_unit_skill_contract_helper.gd")

var _effect_field_helper = EffectFieldContractHelperScript.new()
var _unit_skill_helper = UnitSkillContractHelperScript.new()

func validate_unit_contract(
	validator,
	content_index: BattleContentIndex,
	errors: Array,
	label: String,
	unit_id: String,
	expected_fields: Dictionary
) -> Variant:
	return _unit_skill_helper.validate_unit_contract(
		validator,
		content_index,
		errors,
		label,
		unit_id,
		expected_fields
	)

func validate_unit_contract_descriptor(validator, content_index: BattleContentIndex, errors: Array, descriptor: Dictionary) -> Variant:
	return _unit_skill_helper.validate_unit_contract_descriptor(
		validator,
		content_index,
		errors,
		descriptor
	)

func validate_skill_contracts(validator, content_index: BattleContentIndex, errors: Array, descriptors: Array) -> void:
	_unit_skill_helper.validate_skill_contracts(validator, content_index, errors, descriptors)

func validate_effect_contracts(validator, content_index: BattleContentIndex, errors: Array, descriptors: Array) -> void:
	_effect_field_helper.validate_effect_contracts(validator, content_index, errors, descriptors)

func validate_field_contracts(validator, content_index: BattleContentIndex, errors: Array, descriptors: Array) -> void:
	_effect_field_helper.validate_field_contracts(validator, content_index, errors, descriptors)

func validate_passive_skill_contracts(validator, content_index: BattleContentIndex, errors: Array, descriptors: Array) -> void:
	_unit_skill_helper.validate_passive_skill_contracts(
		validator,
		content_index,
		errors,
		descriptors
	)

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
	return _effect_field_helper.expect_single_payload_shape(
		validator,
		errors,
		label,
		effect_id,
		effect_definition,
		payload_script,
		payload_name,
		expected_fields
	)

func extract_payloads_by_script(effect_definition, payload_script) -> Array:
	return _effect_field_helper.extract_payloads_by_script(effect_definition, payload_script)

func expect_typed_payload_shape(
	validator,
	errors: Array,
	label: String,
	payload,
	payload_script,
	payload_name: String,
	expected_fields: Dictionary
) -> Variant:
	return _effect_field_helper.expect_typed_payload_shape(
		validator,
		errors,
		label,
		payload,
		payload_script,
		payload_name,
		expected_fields
	)

func expect_payload_shape_by_field(
	validator,
	errors: Array,
	label: String,
	payloads: Array,
	match_field_name: String,
	match_field_value,
	payload_script,
	payload_name: String,
	expected_fields: Dictionary
) -> Variant:
	return _effect_field_helper.expect_payload_shape_by_field(
		validator,
		errors,
		label,
		payloads,
		match_field_name,
		match_field_value,
		payload_script,
		payload_name,
		expected_fields
	)
