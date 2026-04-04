extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalGojoValidator

const GojoContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_gojo_contracts.gd")
const GojoDomainContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_gojo_domain_contracts.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

var _contracts = GojoContractsScript.new()
var _domain_contracts = GojoDomainContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_contracts.validate_unit_contract(self, content_index, errors)
	_contracts.validate_core_skill_contract(self, content_index, errors)
	_contracts.validate_marker_contract(self, content_index, errors)
	_validate_mugen_contract(content_index, errors)
	_validate_reverse_ritual_contract(content_index, errors)
	_validate_murasaki_burst(content_index, errors)
	_domain_contracts.validate(self, content_index, errors)

func _validate_mugen_contract(content_index, errors: Array) -> void:
	var label := "formal[gojo].mugen"
	var passive_skill = _require_passive_skill(content_index, errors, label, "gojo_mugen")
	if passive_skill != null:
		_expect_packed_string_array(errors, "%s trigger_names" % label, passive_skill.trigger_names, PackedStringArray(["on_enter"]))
		_expect_packed_string_array(errors, "%s effect_ids" % label, passive_skill.effect_ids, PackedStringArray(["gojo_mugen_incoming_accuracy_down"]))
	var effect_definition = _require_effect(content_index, errors, label, "gojo_mugen_incoming_accuracy_down")
	if effect_definition == null:
		return
	_expect_packed_string_array(errors, "%s effect.trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_enter"]))
	var payload = _extract_single_payload(errors, label, "gojo_mugen_incoming_accuracy_down", effect_definition, RuleModPayloadScript, "rule_mod")
	if payload == null:
		return
	_expect_payload_shape(
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

func _validate_reverse_ritual_contract(content_index, errors: Array) -> void:
	var label := "formal[gojo].reverse_ritual"
	var effect_definition = _require_effect(content_index, errors, label, "gojo_reverse_heal")
	if effect_definition == null:
		return
	_expect_string(errors, "%s effect.scope" % label, effect_definition.scope, "self")
	_expect_string(errors, "%s effect.duration_mode" % label, effect_definition.duration_mode, "permanent")
	_expect_string(errors, "%s effect.stacking" % label, effect_definition.stacking, "none")
	_expect_packed_string_array(errors, "%s effect.trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_cast"]))
	var heal_payload = _extract_single_payload(
		errors,
		label,
		"gojo_reverse_heal",
		effect_definition,
		HealPayloadScript,
		"heal"
	)
	_expect_payload_shape(
		errors,
		"%s effect" % label,
		heal_payload,
		{
			"use_percent": true,
			"percent": 25,
		}
	)

func _validate_murasaki_burst(content_index, errors: Array) -> void:
	var label := "formal[gojo].murasaki_burst"
	var effect_definition = _require_effect(content_index, errors, label, "gojo_murasaki_conditional_burst")
	if effect_definition == null:
		return
	_expect_packed_string_array(
		errors,
		"%s required_target_effects" % label,
		effect_definition.required_target_effects,
		PackedStringArray(["gojo_ao_mark", "gojo_aka_mark"])
	)
	if not bool(effect_definition.required_target_same_owner):
		errors.append("%s required_target_same_owner must be true" % label)
	var damage_payload = _extract_single_payload(
		errors,
		label,
		"gojo_murasaki_conditional_burst",
		effect_definition,
		DamagePayloadScript,
		"damage"
	)
	if damage_payload == null:
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
