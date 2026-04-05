extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalGojoSkillEffectContracts

const GojoContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_gojo_contracts.gd")
const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")

var _contracts = GojoContractsScript.new()
var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate_core_skill_contract(validator, content_index, errors)
	_contracts.validate_marker_contract(validator, content_index, errors)
	_validate_reverse_ritual_contract(validator, content_index, errors)
	_validate_murasaki_burst(validator, content_index, errors)

func _validate_reverse_ritual_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[gojo].reverse_ritual"
	var effect_definition = validator._require_effect(content_index, errors, label, "gojo_reverse_heal")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": "%s effect" % label,
		"effect_id": "gojo_reverse_heal",
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
		"gojo_reverse_heal",
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

func _validate_murasaki_burst(validator, content_index, errors: Array) -> void:
	var label := "formal[gojo].murasaki_burst"
	var effect_definition = validator._require_effect(content_index, errors, label, "gojo_murasaki_conditional_burst")
	if effect_definition == null:
		return
	validator._expect_packed_string_array(
		errors,
		"%s required_target_effects" % label,
		effect_definition.required_target_effects,
		PackedStringArray(["gojo_ao_mark", "gojo_aka_mark"])
	)
	if not bool(effect_definition.required_target_same_owner):
		errors.append("%s required_target_same_owner must be true" % label)
	if effect_definition.payloads.size() != 3:
		errors.append("%s payload count mismatch: expected 3 got %d" % [label, effect_definition.payloads.size()])
		return
	var damage_payload = effect_definition.payloads[0]
	if damage_payload == null or damage_payload.get_script() != DamagePayloadScript:
		errors.append("%s payload[0] must be damage" % label)
		return
	if not bool(damage_payload.use_formula):
		errors.append("%s damage payload must use formula" % label)
	if String(damage_payload.damage_kind) != "special":
		errors.append("%s damage_kind mismatch: expected special got %s" % [
			label,
			String(damage_payload.damage_kind),
		])
	if int(damage_payload.amount) != 32:
		errors.append("%s amount mismatch: expected 32 got %d" % [label, int(damage_payload.amount)])
	_expect_remove_effect_payload_at(validator, effect_definition, errors, label, 1, "gojo_ao_mark")
	_expect_remove_effect_payload_at(validator, effect_definition, errors, label, 2, "gojo_aka_mark")

func _expect_remove_effect_payload_at(validator, effect_definition, errors: Array, label: String, payload_index: int, expected_effect_id: String) -> void:
	var payload = effect_definition.payloads[payload_index]
	if payload == null or payload.get_script() != RemoveEffectPayloadScript:
		errors.append("%s payload[%d] must be remove_effect" % [label, payload_index])
		return
	validator._expect_payload_shape(
		errors,
		"%s payload[%d]" % [label, payload_index],
		payload,
		{"effect_definition_id": expected_effect_id}
	)
