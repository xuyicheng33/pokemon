extends RefCounted
class_name ContentSnapshotFormalObitoSkillContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const EffectContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_obito_effect_contract_helper.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")

var _helper = ContractHelperScript.new()
var _effect_helper = EffectContractHelperScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_validate_skill_contracts(validator, content_index, errors)
	_effect_helper.validate_heal_block_contracts(validator, content_index, errors)
	_effect_helper.validate_yinyang_dun_contracts(validator, content_index, errors)
	_validate_qiudaoyu_contracts(validator, content_index, errors)

func _validate_skill_contracts(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(validator, content_index, errors, [
		{
			"label": "formal[obito].qiudao_jiaotu",
			"skill_id": "obito_qiudao_jiaotu",
			"fields": {
				"display_name": "求道焦土",
				"damage_kind": "special",
				"power": 42,
				"accuracy": 100,
				"mp_cost": 10,
				"priority": 0,
				"combat_type_id": "dark",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["obito_qiudao_jiaotu_heal_block_apply", "obito_qiudao_jiaotu_heal_block_rule_mod"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[obito].yinyang_dun",
			"skill_id": "obito_yinyang_dun",
			"fields": {
				"display_name": "阴阳遁",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 16,
				"priority": 2,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["obito_yinyang_dun_boost_and_charge", "obito_yinyang_dun_guard_rule_mod", "obito_yinyang_dun_guard_stack_listener"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[obito].qiudao_yu",
			"skill_id": "obito_qiudao_yu",
			"fields": {
				"display_name": "求道玉",
				"damage_kind": "special",
				"power": 24,
				"accuracy": 100,
				"mp_cost": 18,
				"priority": 0,
				"combat_type_id": "light",
				"power_bonus_source": "effect_stack_sum",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["obito_qiudao_yu_clear_yinyang"]),
				"effects_on_miss_ids": PackedStringArray(["obito_qiudao_yu_clear_yinyang"]),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[obito].liudao_shizi_fenghuo",
			"skill_id": "obito_liudao_shizi_fenghuo",
			"fields": {
				"display_name": "六道十字奉火",
				"damage_kind": "special",
				"power": 62,
				"accuracy": 90,
				"mp_cost": 24,
				"priority": -1,
				"combat_type_id": "fire",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
	])

func _validate_qiudaoyu_contracts(validator, content_index, errors: Array) -> void:
	var label := "formal[obito].qiudao_yu"
	var skill_definition = validator._require_skill(content_index, errors, label, "obito_qiudao_yu")
	if skill_definition != null:
		validator._expect_packed_string_array(
			errors,
			"%s power_bonus_self_effect_ids" % label,
			skill_definition.power_bonus_self_effect_ids,
			PackedStringArray(["obito_yinyang_zhili"])
		)
		validator._expect_packed_string_array(
			errors,
			"%s power_bonus_target_effect_ids" % label,
			skill_definition.power_bonus_target_effect_ids,
			PackedStringArray()
		)
		validator._expect_int(errors, "%s power_bonus_per_stack" % label, skill_definition.power_bonus_per_stack, 12)
		if not is_equal_approx(float(skill_definition.execute_target_hp_ratio_lte), 0.3):
			errors.append("%s execute_target_hp_ratio_lte mismatch: expected 0.3 got %s" % [
				label,
				var_to_str(float(skill_definition.execute_target_hp_ratio_lte)),
			])
		validator._expect_int(errors, "%s execute_required_total_stacks" % label, skill_definition.execute_required_total_stacks, 5)
		validator._expect_packed_string_array(
			errors,
			"%s execute_self_effect_ids" % label,
			skill_definition.execute_self_effect_ids,
			PackedStringArray(["obito_yinyang_zhili"])
		)
		validator._expect_packed_string_array(
			errors,
			"%s execute_target_effect_ids" % label,
			skill_definition.execute_target_effect_ids,
			PackedStringArray()
		)
	var clear_effect = validator._require_effect(content_index, errors, label, "obito_qiudao_yu_clear_yinyang")
	if clear_effect == null:
		return
	validator._expect_string(errors, "%s clear.scope" % label, clear_effect.scope, "self")
	validator._expect_string(errors, "%s clear.duration_mode" % label, clear_effect.duration_mode, "permanent")
	validator._expect_string(errors, "%s clear.stacking" % label, clear_effect.stacking, "none")
	validator._expect_packed_string_array(errors, "%s clear.trigger_names" % label, clear_effect.trigger_names, PackedStringArray(["on_hit", "on_miss"]))
	var clear_payload = validator._extract_single_payload(
		errors,
		label,
		"obito_qiudao_yu_clear_yinyang",
		clear_effect,
		RemoveEffectPayloadScript,
		"remove_effect"
	)
	validator._expect_payload_shape(
		errors,
		"%s clear.payload" % label,
		clear_payload,
		{"effect_definition_id": "obito_yinyang_zhili", "remove_mode": "all"}
	)
