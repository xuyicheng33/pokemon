extends RefCounted
class_name ContentSnapshotFormalKashimoContracts

const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract_descriptor(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.unit_contract("kashimo")
	)

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	var regular_skill_ids := PackedStringArray([
		"kashimo_raiken",
		"kashimo_charge",
		"kashimo_feedback_strike",
		"kashimo_kyokyo_katsura",
	])
	_helper.validate_skill_contracts(
		validator,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts("kashimo", regular_skill_ids)
	)

func validate_kyokyo_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].kyokyo"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_kyokyo_nullify")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("kashimo", "kashimo_kyokyo_nullify", label)]
	)
	var payload = validator._extract_single_payload(errors, label, "kashimo_kyokyo_nullify", effect_definition, RuleModPayloadScript, "rule_mod")
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "nullify_field_accuracy",
			"mod_op": "set",
			"value": true,
			"scope": "self",
			"duration_mode": "turns",
			"duration": 3,
			"decrement_on": "turn_end",
			"stacking": "refresh",
			"priority": 10,
		}
	)
