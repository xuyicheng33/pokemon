extends RefCounted
class_name ContentSnapshotFormalSukunaSkillEffectContracts

const SukunaContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_sukuna_contracts.gd")
const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")

var _contracts = SukunaContractsScript.new()
var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate_core_skill_contract(validator, content_index, errors)
	_contracts.validate_kamado_contract(validator, content_index, errors)
	_validate_reverse_ritual_contract(validator, content_index, errors)

func _validate_reverse_ritual_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].reverse_ritual"
	var effect_definition = validator._require_effect(content_index, errors, label, "sukuna_reverse_heal")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": "%s effect" % label,
		"effect_id": "sukuna_reverse_heal",
		"fields": {
			"scope": "self",
			"duration_mode": "permanent",
			"stacking": "none",
			"trigger_names": PackedStringArray(["on_cast"]),
		},
	}])
	var heal_payload = validator._extract_single_payload(
		errors,
		label,
		"sukuna_reverse_heal",
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
			"percent": 25,
		}
	)
