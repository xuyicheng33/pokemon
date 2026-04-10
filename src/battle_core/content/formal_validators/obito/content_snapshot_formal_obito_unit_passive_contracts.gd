extends RefCounted
class_name ContentSnapshotFormalObitoUnitPassiveContracts

const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")

var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_validate_unit_contract(validator, content_index, errors)
	_validate_passive_contract(validator, content_index, errors)
	_validate_yinyang_stack_contract(validator, content_index, errors)

func _validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract_descriptor(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.unit_contract("obito_juubi_jinchuriki")
	)

func _validate_passive_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[obito_juubi_jinchuriki].xianren_zhili"
	_helper.validate_passive_skill_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.passive_contract("obito_juubi_jinchuriki", "obito_xianren_zhili", label)]
	)
	var effect_definition = validator._require_effect(content_index, errors, label, "obito_xianren_zhili_heal")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_xianren_zhili_heal", "%s effect" % label)]
	)
	var heal_payload = validator._extract_single_payload(
		errors,
		label,
		"obito_xianren_zhili_heal",
		effect_definition,
		HealPayloadScript,
		"heal"
	)
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		heal_payload,
		{
			"use_percent": true,
			"percent": 10,
			"percent_base": "missing_hp",
		}
	)

func _validate_yinyang_stack_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_yinyang_zhili")]
	)
