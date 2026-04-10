extends RefCounted
class_name ContentSnapshotFormalObitoSkillContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const EffectContractHelperScript := preload("res://src/battle_core/content/formal_validators/obito/content_snapshot_formal_obito_effect_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")

var _helper = ContractHelperScript.new()
var _effect_helper = EffectContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_validate_skill_contracts(validator, content_index, errors)
	_effect_helper.validate_heal_block_contracts(validator, content_index, errors)
	_effect_helper.validate_yinyang_dun_contracts(validator, content_index, errors)
	_validate_qiudaoyu_contracts(validator, content_index, errors)

func _validate_skill_contracts(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts(
			"obito_juubi_jinchuriki",
			PackedStringArray([
				"obito_qiudao_jiaotu",
				"obito_yinyang_dun",
				"obito_qiudao_yu",
				"obito_liudao_shizi_fenghuo",
			])
		)
	)

func _validate_qiudaoyu_contracts(validator, content_index, errors: Array) -> void:
	var label := "formal[obito_juubi_jinchuriki].qiudao_yu"
	var clear_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_yu_clear_yinyang")
	if clear_effect == null:
		return
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("obito_juubi_jinchuriki", "obito_qiudao_yu_clear_yinyang", "%s clear" % label)]
	)
	var clear_payload = validator._extract_single_payload(
		errors,
		label,
		"obito_qiudao_yu_clear_yinyang",
		clear_effect,
		RemoveEffectPayloadScript,
		"remove_effect"
	)
	validator._expect_payload_shape(
		errors,
		"%s clear.payload" % label,
		clear_payload,
		{"effect_definition_id": "obito_yinyang_zhili", "remove_mode": "all"}
	)
