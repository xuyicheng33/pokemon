extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalSukunaValidator

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const SHARED_FIRE_BURST_RESOURCE_PATH := "res://content/shared/effects/sukuna_shared_fire_burst_damage.tres"

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
		FormalCharacterBaselinesScript.unit_contract("sukuna")
	)
	_validate_teach_love_contract(content_index, errors)

func _validate_teach_love_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[sukuna].teach_love"
	_helper.validate_passive_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.passive_contract("sukuna", "sukuna_teach_love", "%s passive" % label)]
	)
	var effect_definition = _require_effect(content_index, errors, label, "sukuna_refresh_love_regen")
	if effect_definition == null:
		return
	_expect_string(errors, "%s effect stacking" % label, effect_definition.stacking, "none")
	var payload = _extract_single_payload(errors, label, "sukuna_refresh_love_regen", effect_definition, RuleModPayloadScript, "rule_mod")
	_expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "mp_regen",
			"mod_op": "add",
			"duration_mode": "permanent",
			"decrement_on": "turn_start",
			"stacking": "replace",
			"dynamic_value_formula": "matchup_bst_gap_band",
			"dynamic_value_default": 0.0,
		}
	)
	if payload != null:
		if payload.dynamic_value_thresholds != PackedInt32Array([20, 40, 70, 110, 160]):
			errors.append("%s effect.dynamic_value_thresholds mismatch: expected %s got %s" % [label, var_to_str(PackedInt32Array([20, 40, 70, 110, 160])), var_to_str(payload.dynamic_value_thresholds)])
		if payload.dynamic_value_outputs != PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0]):
			errors.append("%s effect.dynamic_value_outputs mismatch: expected %s got %s" % [label, var_to_str(PackedFloat32Array([9.0, 8.0, 7.0, 6.0, 5.0])), var_to_str(payload.dynamic_value_outputs)])

func _validate_skill_effect(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		FormalCharacterBaselinesScript.skill_contracts(
			"sukuna",
			PackedStringArray([
				"sukuna_kai",
				"sukuna_hatsu",
				"sukuna_hiraku",
				"sukuna_reverse_ritual",
			])
		)
	)
	_validate_kamado_contract(content_index, errors)
	_validate_reverse_ritual_contract(content_index, errors)

func _validate_kamado_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[sukuna].kamado"
	var apply_effect = _require_effect(content_index, errors, label, "sukuna_apply_kamado")
	if apply_effect != null:
		var apply_payload = _extract_single_payload(errors, label, "sukuna_apply_kamado", apply_effect, ApplyEffectPayloadScript, "apply_effect")
		_expect_payload_shape(errors, "%s apply" % label, apply_payload, {"effect_definition_id": "sukuna_kamado_mark"})
	var marker_effect = _require_effect(content_index, errors, label, "sukuna_kamado_mark")
	if marker_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("sukuna", "sukuna_kamado_mark", "%s mark" % label)]
		)

func _validate_reverse_ritual_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[sukuna].reverse_ritual"
	_validate_single_payload_effect(
		content_index, errors,
		"sukuna", label, "sukuna_reverse_heal",
		HealPayloadScript, "heal",
		{
			"use_percent": true,
			"percent": 25,
		}
	)

func _validate_ultimate_domain(content_index: BattleContentIndex, errors: Array) -> void:
	_helper.validate_skill_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.skill_contract("sukuna", "sukuna_fukuma_mizushi")]
	)
	_validate_domain_contract(content_index, errors)
	_validate_shared_damage_payload_resource(
		content_index,
		errors,
		"formal[sukuna].shared_fire_burst",
		PackedStringArray(["sukuna_kamado_mark", "sukuna_kamado_explode", "sukuna_domain_expire_burst"]),
		SHARED_FIRE_BURST_RESOURCE_PATH,
		{
			"amount": 20,
			"use_formula": false,
			"combat_type_id": "fire",
		}
	)

func _validate_domain_contract(content_index: BattleContentIndex, errors: Array) -> void:
	var label := "formal[sukuna].domain"
	var apply_effect = _require_effect(content_index, errors, label, "sukuna_apply_domain_field")
	if apply_effect != null:
		_helper.validate_effect_contracts(
			self,
			content_index,
			errors,
			[FormalCharacterBaselinesScript.effect_contract("sukuna", "sukuna_apply_domain_field", "%s apply" % label)]
		)
		var apply_payload = _extract_single_payload(errors, label, "sukuna_apply_domain_field", apply_effect, ApplyFieldPayloadScript, "apply_field")
		_expect_payload_shape(
			errors,
			"%s apply" % label,
			apply_payload,
			{"field_definition_id": "sukuna_malevolent_shrine_field"}
		)
	_helper.validate_field_contracts(
		self,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.field_contract("sukuna", "sukuna_malevolent_shrine_field", "%s field" % label)]
	)
	var expire_burst = _require_effect(content_index, errors, label, "sukuna_domain_expire_burst")
	if expire_burst != null:
		_expect_packed_string_array(errors, "%s effect[sukuna_domain_expire_burst].trigger_names" % label, expire_burst.trigger_names, PackedStringArray(["field_expire"]))
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_cast_buff", "attack", 1, 0, PackedStringArray(["field_apply"]))
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_cast_buff", "sp_attack", 1, 1, PackedStringArray(["field_apply"]))
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_buff_remove", "attack", -1, 0, PackedStringArray(["field_break", "field_expire"]))
	_validate_domain_stat_mod(content_index, errors, label, "sukuna_domain_buff_remove", "sp_attack", -1, 1, PackedStringArray(["field_break", "field_expire"]))

func _validate_domain_stat_mod(content_index: BattleContentIndex, errors: Array, label: String, effect_id: String, stat_name: String, stage_delta: int, payload_index: int, expected_trigger_names: PackedStringArray) -> void:
	var effect_definition = _require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	_expect_string(errors, "%s effect[%s].scope" % [label, effect_id], effect_definition.scope, "self")
	_expect_string(errors, "%s effect[%s].duration_mode" % [label, effect_id], effect_definition.duration_mode, "permanent")
	_expect_string(errors, "%s effect[%s].stacking" % [label, effect_id], effect_definition.stacking, "none")
	_expect_packed_string_array(errors, "%s effect[%s].trigger_names" % [label, effect_id], effect_definition.trigger_names, expected_trigger_names)
	if effect_definition.payloads.size() <= payload_index:
		errors.append("%s effect[%s] missing payload index %d" % [label, effect_id, payload_index])
		return
	var payload = effect_definition.payloads[payload_index]
	if payload == null or payload.get_script() != StatModPayloadScript:
		errors.append("%s effect[%s] payload[%d] must be stat_mod" % [label, effect_id, payload_index])
		return
	_expect_payload_shape(errors, "%s effect[%s].payload[%d]" % [label, effect_id, payload_index], payload, {"stat_name": stat_name, "stage_delta": stage_delta})

func _validate_shared_damage_payload_resource(content_index: BattleContentIndex, errors: Array, label: String, effect_ids: PackedStringArray, expected_resource_path: String, expected_fields: Dictionary) -> void:
	for raw_effect_id in effect_ids:
		var effect_id := String(raw_effect_id)
		var effect_definition = _require_effect(content_index, errors, label, effect_id)
		if effect_definition == null:
			return
		var damage_payload = _extract_single_payload(
			errors,
			label,
			effect_id,
			effect_definition,
			DamagePayloadScript,
			"damage"
		)
		if damage_payload == null:
			continue
		_expect_payload_shape(errors, "%s effect[%s]" % [label, effect_id], damage_payload, expected_fields)
		var resource_path := String(damage_payload.resource_path)
		if resource_path != expected_resource_path:
			errors.append("%s effect[%s] must reuse payload resource %s, got %s" % [
				label,
				effect_id,
				expected_resource_path,
				resource_path,
			])
