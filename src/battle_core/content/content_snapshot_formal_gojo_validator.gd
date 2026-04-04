extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalGojoValidator

const GojoContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_gojo_contracts.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _contracts = GojoContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_contracts.validate_unit_contract(self, content_index, errors)
	_contracts.validate_core_skill_contract(self, content_index, errors)
	_contracts.validate_marker_contract(self, content_index, errors)
	_validate_mugen_contract(content_index, errors)
	_validate_reverse_ritual_contract(content_index, errors)
	_validate_murasaki_burst(content_index, errors)
	_validate_domain_followup(content_index, errors)
	_validate_domain_buff_contract(content_index, errors)

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

func _validate_domain_followup(content_index, errors: Array) -> void:
	var label := "formal[gojo].domain_followup"
	var effect_definition = _require_effect(content_index, errors, label, "gojo_apply_domain_field")
	if effect_definition == null:
		return
	var apply_field_payload = _extract_single_payload(
		errors,
		label,
		"gojo_apply_domain_field",
		effect_definition,
		ApplyFieldPayloadScript,
		"apply_field"
	)
	if apply_field_payload == null:
		return
	if String(apply_field_payload.field_definition_id) != "gojo_unlimited_void_field":
		errors.append("%s field_definition_id mismatch: expected gojo_unlimited_void_field got %s" % [
			label,
			String(apply_field_payload.field_definition_id),
		])
	_expect_packed_string_array(
		errors,
		"%s trigger_names" % label,
		effect_definition.trigger_names,
		PackedStringArray(["on_hit"])
	)
	_expect_packed_string_array(
		errors,
		"%s on_success_effect_ids" % label,
		apply_field_payload.on_success_effect_ids,
		PackedStringArray(["gojo_domain_action_lock"])
	)

func _validate_domain_buff_contract(content_index, errors: Array) -> void:
	var label := "formal[gojo].domain_buff_contract"
	var field_definition = _require_field(content_index, errors, label, "gojo_unlimited_void_field")
	if field_definition != null:
		_expect_packed_string_array(
			errors,
			"%s field.effect_ids" % label,
			field_definition.effect_ids,
			PackedStringArray(["gojo_domain_cast_buff"])
		)
		_expect_packed_string_array(
			errors,
			"%s field.on_expire_effect_ids" % label,
			field_definition.on_expire_effect_ids,
			PackedStringArray(["gojo_domain_buff_remove"])
		)
		_expect_packed_string_array(
			errors,
			"%s field.on_break_effect_ids" % label,
			field_definition.on_break_effect_ids,
			PackedStringArray(["gojo_domain_buff_remove"])
		)
		_expect_int(errors, "%s field.creator_accuracy_override" % label, field_definition.creator_accuracy_override, 100)
	var action_lock_effect = _require_effect(content_index, errors, label, "gojo_domain_action_lock")
	if action_lock_effect != null:
		_expect_packed_string_array(
			errors,
			"%s action_lock.trigger_names" % label,
			action_lock_effect.trigger_names,
			PackedStringArray(["field_apply_success"])
		)
		var action_lock_payload = _extract_single_payload(
			errors,
			label,
			"gojo_domain_action_lock",
			action_lock_effect,
			RuleModPayloadScript,
			"rule_mod"
		)
		_expect_payload_shape(
			errors,
			"%s action_lock" % label,
			action_lock_payload,
			{
				"mod_kind": "action_legality",
				"mod_op": "deny",
				"value": "all",
				"duration_mode": "turns",
				"duration": 1,
				"decrement_on": "turn_end",
			}
		)
	_validate_stat_mod_effect(content_index, errors, label, "gojo_domain_cast_buff", "sp_attack", 1)
	_validate_stat_mod_effect(content_index, errors, label, "gojo_domain_buff_remove", "sp_attack", -1)

func _validate_stat_mod_effect(
	content_index,
	errors: Array,
	label: String,
	effect_id: String,
	expected_stat_name: String,
	expected_stage_delta: int
) -> void:
	var effect_definition = _require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	var stat_mod_payload = _extract_single_payload(
		errors,
		label,
		effect_id,
		effect_definition,
		StatModPayloadScript,
		"stat_mod"
	)
	if stat_mod_payload == null:
		return
	if String(stat_mod_payload.stat_name) != expected_stat_name:
		errors.append("%s effect[%s].stat_name mismatch: expected %s got %s" % [
			label,
			effect_id,
			expected_stat_name,
			String(stat_mod_payload.stat_name),
		])
	if int(stat_mod_payload.stage_delta) != expected_stage_delta:
		errors.append("%s effect[%s].stage_delta mismatch: expected %d got %d" % [
			label,
			effect_id,
			expected_stage_delta,
			int(stat_mod_payload.stage_delta),
		])
