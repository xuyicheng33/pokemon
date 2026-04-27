extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalGojoValidator

const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate(content_index: BattleContentIndex, errors: Array) -> void:
	_validate_unit_passive(content_index, errors)
	_validate_skill_effect(content_index, errors)
	_validate_ultimate_domain(content_index, errors)

func _validate_unit_passive(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_unit_contract_descriptor(
		self,
		content_index,
		errors,
		FormalCharacterBaselinesScript.unit_contract("gojo_satoru")
	)
	_validate_mugen_contract(content_index, errors)

func _validate_mugen_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[gojo_satoru].mugen"
	_helper.validate_passive_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.passive_contract("gojo_satoru", "gojo_mugen", label)]
	)
	_validate_single_payload_effect(
		content_index, errors,
		"gojo_satoru", label, "gojo_mugen_incoming_accuracy_down",
		RuleModPayloadScript, "rule_mod",
		{
			"mod_kind": "incoming_accuracy",
			"mod_op": "add",
			"value": -10,
			"scope": "self",
			"duration_mode": "permanent",
			"stacking": "none",
		}
	)

func _validate_skill_effect(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts(
			"gojo_satoru",
			PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"])
		)
	)
	_validate_marker_contract(content_index, errors)
	_validate_reverse_ritual_contract(content_index, errors)
	_validate_murasaki_burst(content_index, errors)

func _validate_marker_contract(content_index: BattleContentIndex, errors: Array) -> void:
	_validate_marker_effect(content_index, errors, "formal[gojo_satoru].ao_mark", "gojo_ao_mark", "gojo_ao_speed_up", "speed", 1)
	_validate_marker_effect(content_index, errors, "formal[gojo_satoru].aka_mark", "gojo_aka_mark", "gojo_aka_slow_down", "speed", -1)

func _validate_marker_effect(
	content_index: BattleContentIndex,
	errors: Array,
	label: String,
	marker_effect_id: String,
	stat_effect_id: String,
	expected_stat_name: String,
	expected_stage_delta: int
) -> void:
	var marker_effect = _require_effect(content_index, errors, label, marker_effect_id)
	if marker_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("gojo_satoru", marker_effect_id, label)]
		)
	var apply_effect_id := "%s_apply" % marker_effect_id
	_expect_apply_effect_target(
		content_index, errors, label, apply_effect_id, marker_effect_id,
		"%s effect[%s]" % [label, apply_effect_id]
	)
	_expect_payload_target(
		content_index, errors,
		label, stat_effect_id,
		StatModPayloadScript, "stat_mod",
		{
			"stat_name": expected_stat_name,
			"stage_delta": expected_stage_delta,
		},
		"%s effect[%s]" % [label, stat_effect_id]
	)

func _validate_reverse_ritual_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[gojo_satoru].reverse_ritual"
	_validate_single_payload_effect(
		content_index, errors,
		"gojo_satoru", label, "gojo_reverse_heal",
		HealPayloadScript, "heal",
		{
			"use_percent": true,
			"percent": 25,
		}
	)

func _validate_murasaki_burst(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[gojo_satoru].murasaki_burst"
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
	_expect_remove_effect_payload_at(effect_definition, errors, label, 1, "gojo_ao_mark")
	_expect_remove_effect_payload_at(effect_definition, errors, label, 2, "gojo_aka_mark")

func _expect_remove_effect_payload_at(effect_definition, errors: Array, label: String, payload_index: int, expected_effect_id: String) -> void:
	var payload = effect_definition.payloads[payload_index]
	if payload == null or payload.get_script() != RemoveEffectPayloadScript:
		errors.append("%s payload[%d] must be remove_effect" % [label, payload_index])
		return
	_expect_payload_shape(
		errors,
		"%s payload[%d]" % [label, payload_index],
		payload,
		{"effect_definition_id": expected_effect_id}
	)

func _validate_ultimate_domain(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.skill_contract("gojo_satoru", "gojo_unlimited_void")]
	)
	_validate_domain_followup(content_index, errors)
	_validate_domain_buff_contract(content_index, errors)

func _validate_domain_followup(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[gojo_satoru].domain_followup"
	var effect_definition = _require_effect(content_index, errors, label, "gojo_apply_domain_field")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.effect_contract("gojo_satoru", "gojo_apply_domain_field", label)]
	)
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

func _validate_domain_buff_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[gojo_satoru].domain_buff_contract"
	_helper.validate_field_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.field_contract("gojo_satoru", "gojo_unlimited_void_field", "%s field" % label)]
	)
	var action_lock_effect = _require_effect(content_index, errors, label, "gojo_domain_action_lock")
	if action_lock_effect != null:
		_helper.validate_effect_contracts(self, content_index, errors, [{
			"label": "%s action_lock" % label,
			"effect_id": "gojo_domain_action_lock",
			"fields": {
				"display_name": "无量空处行动封锁",
				"scope": "target",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["field_apply_success"]),
			},
		}])
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
				"stacking": "replace",
			}
		)
	_validate_stat_mod_effect(content_index, errors, label, "gojo_domain_cast_buff", "sp_attack", 1, PackedStringArray(["field_apply"]))
	_validate_stat_mod_effect(content_index, errors, label, "gojo_domain_buff_remove", "sp_attack", -1, PackedStringArray(["field_break", "field_expire"]))

func _validate_stat_mod_effect(
	content_index: BattleContentIndex,
	errors: Array,
	label: String,
	effect_id: String,
	expected_stat_name: String,
	expected_stage_delta: int,
	expected_trigger_names: PackedStringArray
) -> void:
	_helper.validate_effect_contracts(self, content_index, errors, [{
		"label": "%s effect[%s]" % [label, effect_id],
		"effect_id": effect_id,
		"fields": {
			"scope": "self",
			"duration_mode": "permanent",
			"stacking": "none",
			"trigger_names": expected_trigger_names,
		},
	}])
	_expect_payload_target(
		content_index, errors,
		label, effect_id,
		StatModPayloadScript, "stat_mod",
		{"stat_name": expected_stat_name, "stage_delta": expected_stage_delta},
		"%s effect[%s]" % [label, effect_id]
	)
