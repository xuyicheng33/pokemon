extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalSukunaValidator

const SukunaContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_sukuna_contracts.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _contracts = SukunaContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_contracts.validate_unit_contract(self, content_index, errors)
	_contracts.validate_core_skill_contract(self, content_index, errors)
	_contracts.validate_kamado_contract(self, content_index, errors)
	_validate_reverse_ritual_contract(content_index, errors)
	_validate_domain_contract(content_index, errors)
	_contracts.validate_teach_love_contract(self, content_index, errors)
	_validate_matching_damage_payloads(
		content_index, errors, "formal[sukuna].shared_fire_burst", PackedStringArray(["sukuna_kamado_mark", "sukuna_kamado_explode", "sukuna_domain_expire_burst"])
	)

func _validate_reverse_ritual_contract(content_index, errors: Array) -> void:
	var label := "formal[sukuna].reverse_ritual"
	var effect_definition = _require_effect(content_index, errors, label, "sukuna_reverse_heal")
	if effect_definition == null:
		return
	_expect_string(errors, "%s effect.scope" % label, effect_definition.scope, "self")
	_expect_string(errors, "%s effect.duration_mode" % label, effect_definition.duration_mode, "permanent")
	_expect_string(errors, "%s effect.stacking" % label, effect_definition.stacking, "none")
	_expect_packed_string_array(errors, "%s effect.trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_cast"]))
	var heal_payload = _extract_single_payload(
		errors,
		label,
		"sukuna_reverse_heal",
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

func _validate_domain_contract(content_index, errors: Array) -> void:
	var label := "formal[sukuna].domain"
	var apply_effect = _require_effect(content_index, errors, label, "sukuna_apply_domain_field")
	if apply_effect != null:
		var apply_payload = _extract_single_payload(errors, label, "sukuna_apply_domain_field", apply_effect, ApplyFieldPayloadScript, "apply_field")
		_expect_payload_shape(
			errors,
			"%s apply" % label,
			apply_payload,
			{"field_definition_id": "sukuna_malevolent_shrine_field"}
		)
		_expect_string(errors, "%s apply.duration_mode" % label, apply_effect.duration_mode, "turns")
		_expect_int(errors, "%s apply.duration" % label, apply_effect.duration, 3)
		_expect_string(errors, "%s apply.decrement_on" % label, apply_effect.decrement_on, "turn_end")
	var field_definition = _require_field(content_index, errors, label, "sukuna_malevolent_shrine_field")
	if field_definition != null:
		_expect_packed_string_array(errors, "%s field.effect_ids" % label, field_definition.effect_ids, PackedStringArray(["sukuna_domain_cast_buff"]))
		_expect_packed_string_array(errors, "%s field.on_expire_effect_ids" % label, field_definition.on_expire_effect_ids, PackedStringArray(["sukuna_domain_buff_remove", "sukuna_domain_expire_burst"]))
		_expect_packed_string_array(errors, "%s field.on_break_effect_ids" % label, field_definition.on_break_effect_ids, PackedStringArray(["sukuna_domain_buff_remove"]))
		_expect_int(errors, "%s field.creator_accuracy_override" % label, field_definition.creator_accuracy_override, 100)
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_cast_buff", "attack", 1, 0)
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_cast_buff", "sp_attack", 1, 1)
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_buff_remove", "attack", -1, 0)
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_buff_remove", "sp_attack", -1, 1)

func _validate_domain_stat_mod(content_index, errors: Array, label: String, effect_id: String, stat_name: String, stage_delta: int, payload_index: int) -> void:
	var effect_definition = _require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	if effect_definition.payloads.size() <= payload_index:
		errors.append("%s effect[%s] missing payload index %d" % [label, effect_id, payload_index])
		return
	var payload = effect_definition.payloads[payload_index]
	if payload == null or payload.get_script() != StatModPayloadScript:
		errors.append("%s effect[%s] payload[%d] must be stat_mod" % [label, effect_id, payload_index])
		return
	_expect_payload_shape(errors, "%s effect[%s].payload[%d]" % [label, effect_id, payload_index], payload, {"stat_name": stat_name, "stage_delta": stage_delta})


func _validate_matching_damage_payloads(content_index, errors: Array, label: String, effect_ids: PackedStringArray) -> void:
	var baseline_fingerprint: Dictionary = {}
	var baseline_effect_id := ""
	for raw_effect_id in effect_ids:
		var effect_id := String(raw_effect_id)
		var effect_definition = _require_effect(content_index, errors, label, effect_id)
		if effect_definition == null:
			return
		var damage_payload = _extract_single_damage_payload(errors, label, effect_id, effect_definition)
		if damage_payload == null:
			continue
		var fingerprint := {
			"amount": int(damage_payload.amount),
			"use_formula": bool(damage_payload.use_formula),
			"combat_type_id": String(damage_payload.combat_type_id),
		}
		if baseline_effect_id.is_empty():
			baseline_effect_id = effect_id
			baseline_fingerprint = fingerprint
			continue
		if fingerprint != baseline_fingerprint:
			errors.append("%s payload mismatch: effect[%s]=%s expected effect[%s]=%s" % [
				label,
				effect_id,
				var_to_str(fingerprint),
				baseline_effect_id,
				var_to_str(baseline_fingerprint),
			])

func _extract_single_damage_payload(errors: Array, label: String, effect_id: String, effect_definition) -> Variant:
	return _extract_single_payload(
		errors,
		label,
		effect_id,
		effect_definition,
		DamagePayloadScript,
		"damage"
	)
