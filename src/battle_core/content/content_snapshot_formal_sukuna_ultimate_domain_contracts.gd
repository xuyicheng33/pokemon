extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalSukunaUltimateDomainContracts

const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const SHARED_FIRE_BURST_RESOURCE_PATH := "res://content/shared/effects/sukuna_shared_fire_burst_damage.tres"

var _helper = ContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(validator, content_index, errors, [{
		"label": "formal[sukuna].fukuma_mizushi",
		"skill_id": "sukuna_fukuma_mizushi",
		"fields": {
			"display_name": "伏魔御厨子",
			"damage_kind": "special",
			"power": 68,
			"accuracy": 100,
			"mp_cost": 50,
			"priority": 5,
			"combat_type_id": "demon",
			"targeting": "enemy_active_slot",
			"is_domain_skill": true,
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(["sukuna_apply_domain_field"]),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		},
	}])
	_validate_domain_contract(validator, content_index, errors)
	_validate_shared_damage_payload_resource(
		validator,
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

func _validate_domain_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].domain"
	var apply_effect = validator._require_effect(content_index, errors, label, "sukuna_apply_domain_field")
	if apply_effect != null:
		var apply_payload = validator._extract_single_payload(errors, label, "sukuna_apply_domain_field", apply_effect, ApplyFieldPayloadScript, "apply_field")
		validator._expect_payload_shape(
			errors,
			"%s apply" % label,
			apply_payload,
			{"field_definition_id": "sukuna_malevolent_shrine_field"}
		)
		validator._expect_string(errors, "%s apply.scope" % label, apply_effect.scope, "field")
		validator._expect_string(errors, "%s apply.duration_mode" % label, apply_effect.duration_mode, "turns")
		validator._expect_int(errors, "%s apply.duration" % label, apply_effect.duration, 3)
		validator._expect_string(errors, "%s apply.decrement_on" % label, apply_effect.decrement_on, "turn_end")
		validator._expect_string(errors, "%s apply.stacking" % label, apply_effect.stacking, "replace")
		validator._expect_packed_string_array(errors, "%s apply.trigger_names" % label, apply_effect.trigger_names, PackedStringArray(["on_hit"]))
	var field_definition = validator._require_field(content_index, errors, label, "sukuna_malevolent_shrine_field")
	if field_definition != null:
		validator._expect_string(errors, "%s field.field_kind" % label, field_definition.field_kind, "domain")
		validator._expect_packed_string_array(errors, "%s field.effect_ids" % label, field_definition.effect_ids, PackedStringArray(["sukuna_domain_cast_buff"]))
		validator._expect_packed_string_array(errors, "%s field.on_expire_effect_ids" % label, field_definition.on_expire_effect_ids, PackedStringArray(["sukuna_domain_buff_remove", "sukuna_domain_expire_burst"]))
		validator._expect_packed_string_array(errors, "%s field.on_break_effect_ids" % label, field_definition.on_break_effect_ids, PackedStringArray(["sukuna_domain_buff_remove"]))
		validator._expect_int(errors, "%s field.creator_accuracy_override" % label, field_definition.creator_accuracy_override, 100)
	var expire_burst = validator._require_effect(content_index, errors, label, "sukuna_domain_expire_burst")
	if expire_burst != null:
		validator._expect_packed_string_array(errors, "%s effect[sukuna_domain_expire_burst].trigger_names" % label, expire_burst.trigger_names, PackedStringArray(["field_expire"]))
	_validate_domain_stat_mod(validator, content_index, errors, label, "sukuna_domain_cast_buff", "attack", 1, 0, PackedStringArray(["field_apply"]))
	_validate_domain_stat_mod(validator, content_index, errors, label, "sukuna_domain_cast_buff", "sp_attack", 1, 1, PackedStringArray(["field_apply"]))
	_validate_domain_stat_mod(validator, content_index, errors, label, "sukuna_domain_buff_remove", "attack", -1, 0, PackedStringArray(["field_break", "field_expire"]))
	_validate_domain_stat_mod(validator, content_index, errors, label, "sukuna_domain_buff_remove", "sp_attack", -1, 1, PackedStringArray(["field_break", "field_expire"]))

func _validate_domain_stat_mod(validator, content_index, errors: Array, label: String, effect_id: String, stat_name: String, stage_delta: int, payload_index: int, expected_trigger_names: PackedStringArray) -> void:
	var effect_definition = validator._require_effect(content_index, errors, label, effect_id)
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s effect[%s].scope" % [label, effect_id], effect_definition.scope, "self")
	validator._expect_string(errors, "%s effect[%s].duration_mode" % [label, effect_id], effect_definition.duration_mode, "permanent")
	validator._expect_string(errors, "%s effect[%s].stacking" % [label, effect_id], effect_definition.stacking, "none")
	validator._expect_packed_string_array(errors, "%s effect[%s].trigger_names" % [label, effect_id], effect_definition.trigger_names, expected_trigger_names)
	if effect_definition.payloads.size() <= payload_index:
		errors.append("%s effect[%s] missing payload index %d" % [label, effect_id, payload_index])
		return
	var payload = effect_definition.payloads[payload_index]
	if payload == null or payload.get_script() != StatModPayloadScript:
		errors.append("%s effect[%s] payload[%d] must be stat_mod" % [label, effect_id, payload_index])
		return
	validator._expect_payload_shape(errors, "%s effect[%s].payload[%d]" % [label, effect_id, payload_index], payload, {"stat_name": stat_name, "stage_delta": stage_delta})

func _validate_shared_damage_payload_resource(validator, content_index, errors: Array, label: String, effect_ids: PackedStringArray, expected_resource_path: String, expected_fields: Dictionary) -> void:
	for raw_effect_id in effect_ids:
		var effect_id := String(raw_effect_id)
		var effect_definition = validator._require_effect(content_index, errors, label, effect_id)
		if effect_definition == null:
			return
		var damage_payload = validator._extract_single_payload(
			errors,
			label,
			effect_id,
			effect_definition,
			DamagePayloadScript,
			"damage"
		)
		if damage_payload == null:
			continue
		validator._expect_payload_shape(errors, "%s effect[%s]" % [label, effect_id], damage_payload, expected_fields)
		var resource_path := String(damage_payload.resource_path)
		if resource_path != expected_resource_path:
			errors.append("%s effect[%s] must reuse payload resource %s, got %s" % [
				label,
				effect_id,
				expected_resource_path,
				resource_path,
			])
