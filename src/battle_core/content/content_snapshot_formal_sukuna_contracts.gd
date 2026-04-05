extends RefCounted
class_name ContentSnapshotFormalSukunaContracts

const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const ContractHelperScript := preload("res://src/battle_core/content/content_snapshot_formal_character_contract_helper.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract(
		validator,
		content_index,
		errors,
		"formal[sukuna].unit",
		"sukuna",
		{
			"display_name": "宿傩",
			"base_hp": 126,
			"base_attack": 78,
			"base_defense": 62,
			"base_sp_attack": 84,
			"base_sp_defense": 60,
			"base_speed": 76,
			"max_mp": 100,
			"init_mp": 45,
			"regen_per_turn": 12,
			"ultimate_points_required": 3,
			"ultimate_points_cap": 3,
			"ultimate_point_gain_on_regular_skill_cast": 1,
			"combat_type_ids": PackedStringArray(["fire", "demon"]),
			"skill_ids": PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"]),
			"candidate_skill_ids": PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku", "sukuna_reverse_ritual"]),
			"ultimate_skill_id": "sukuna_fukuma_mizushi",
			"passive_skill_id": "sukuna_teach_love",
		}
	)

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(validator, content_index, errors, [
		{
			"label": "formal[sukuna].kai",
			"skill_id": "sukuna_kai",
			"fields": {
				"display_name": "解",
				"damage_kind": "physical",
				"power": 42,
				"accuracy": 100,
				"mp_cost": 10,
				"priority": 1,
				"combat_type_id": "",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[sukuna].hatsu",
			"skill_id": "sukuna_hatsu",
			"fields": {
				"display_name": "捌",
				"damage_kind": "special",
				"power": 46,
				"accuracy": 95,
				"mp_cost": 18,
				"priority": -1,
				"combat_type_id": "",
				"targeting": "enemy_active_slot",
				"power_bonus_source": "mp_diff_clamped",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[sukuna].hiraku",
			"skill_id": "sukuna_hiraku",
			"fields": {
				"display_name": "开",
				"damage_kind": "special",
				"power": 48,
				"accuracy": 90,
				"mp_cost": 22,
				"priority": -2,
				"combat_type_id": "fire",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["sukuna_apply_kamado"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[sukuna].reverse_ritual",
			"skill_id": "sukuna_reverse_ritual",
			"fields": {
				"display_name": "反转术式",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 14,
				"priority": 0,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["sukuna_reverse_heal"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
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
		},
	])

func validate_kamado_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].kamado"
	var apply_effect = validator._require_effect(content_index, errors, label, "sukuna_apply_kamado")
	if apply_effect != null:
		validator._expect_packed_string_array(errors, "%s apply.trigger_names" % label, apply_effect.trigger_names, PackedStringArray(["on_hit"]))
		var apply_payload = validator._extract_single_payload(errors, label, "sukuna_apply_kamado", apply_effect, ApplyEffectPayloadScript, "apply_effect")
		validator._expect_payload_shape(errors, "%s apply" % label, apply_payload, {"effect_definition_id": "sukuna_kamado_mark"})
	var marker_effect = validator._require_effect(content_index, errors, label, "sukuna_kamado_mark")
	if marker_effect != null:
		validator._expect_string(errors, "%s mark.duration_mode" % label, marker_effect.duration_mode, "turns")
		validator._expect_int(errors, "%s mark.duration" % label, marker_effect.duration, 3)
		validator._expect_string(errors, "%s mark.decrement_on" % label, marker_effect.decrement_on, "turn_end")
		validator._expect_string(errors, "%s mark.stacking" % label, marker_effect.stacking, "stack")
		validator._expect_int(errors, "%s mark.max_stacks" % label, marker_effect.max_stacks, 3)
		validator._expect_packed_string_array(errors, "%s mark.trigger_names" % label, marker_effect.trigger_names, PackedStringArray(["on_exit"]))
		validator._expect_packed_string_array(errors, "%s mark.on_expire_effect_ids" % label, marker_effect.on_expire_effect_ids, PackedStringArray(["sukuna_kamado_explode"]))
		validator._expect_bool(errors, "%s mark.persists_on_switch" % label, marker_effect.persists_on_switch, false)

func validate_teach_love_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[sukuna].teach_love"
	_helper.validate_passive_skill_contracts(validator, content_index, errors, [{
		"label": "%s passive" % label,
		"passive_skill_id": "sukuna_teach_love",
		"fields": {
			"trigger_names": PackedStringArray(["on_matchup_changed"]),
			"effect_ids": PackedStringArray(["sukuna_refresh_love_regen"]),
		},
	}])
	var effect_definition = validator._require_effect(content_index, errors, label, "sukuna_refresh_love_regen")
	if effect_definition == null:
		return
	_helper.validate_effect_contracts(validator, content_index, errors, [{
		"label": "%s effect" % label,
		"effect_id": "sukuna_refresh_love_regen",
		"fields": {
			"trigger_names": PackedStringArray(["on_matchup_changed"]),
		},
	}])
	var payload = validator._extract_single_payload(errors, label, "sukuna_refresh_love_regen", effect_definition, RuleModPayloadScript, "rule_mod")
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "mp_regen",
			"mod_op": "add",
			"duration_mode": "turns",
			"duration": 999,
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
