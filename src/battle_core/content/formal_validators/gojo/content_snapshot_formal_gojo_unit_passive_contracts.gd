extends RefCounted
class_name ContentSnapshotFormalGojoUnitPassiveContracts

const GojoContractsScript := preload("res://src/battle_core/content/formal_validators/gojo/content_snapshot_formal_gojo_contracts.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

var _contracts = GojoContractsScript.new()
var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate_unit_contract(validator, content_index, errors)
	_validate_mugen_contract(validator, content_index, errors)

func _validate_mugen_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[gojo].mugen"
	_helper.validate_passive_skill_contracts(validator, content_index, errors, [{
		"label": label,
		"passive_skill_id": "gojo_mugen",
		"fields": {
			"trigger_names": PackedStringArray(["on_enter"]),
			"effect_ids": PackedStringArray(["gojo_mugen_incoming_accuracy_down"]),
		},
	}])
	var effect_definition = validator._require_effect(content_index, errors, label, "gojo_mugen_incoming_accuracy_down")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": "%s effect" % label,
		"effect_id": "gojo_mugen_incoming_accuracy_down",
		"fields": {
			"trigger_names": PackedStringArray(["on_enter"]),
		},
	}])
	var payload = validator._extract_single_payload(errors, label, "gojo_mugen_incoming_accuracy_down", effect_definition, RuleModPayloadScript, "rule_mod")
	if payload == null:
		return
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "incoming_accuracy",
			"mod_op": "add",
			"value": -10,
			"scope": "self",
			"duration_mode": "permanent",
			"stacking": "none",
		}
	)
