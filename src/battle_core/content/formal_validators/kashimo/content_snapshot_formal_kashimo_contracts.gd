extends RefCounted
class_name ContentSnapshotFormalKashimoContracts

const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

var _helper = ContractHelperScript.new()

func validate_unit_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_unit_contract(
		validator,
		content_index,
		errors,
		"formal[kashimo].unit",
		"kashimo_hajime",
		{
			"display_name": "鹿紫云一",
			"base_hp": 118,
			"base_attack": 82,
			"base_defense": 58,
			"base_sp_attack": 72,
			"base_sp_defense": 54,
			"base_speed": 90,
			"max_mp": 100,
			"init_mp": 40,
			"regen_per_turn": 10,
			"ultimate_points_required": 3,
			"ultimate_points_cap": 3,
			"ultimate_point_gain_on_regular_skill_cast": 1,
			"combat_type_ids": PackedStringArray(["thunder", "fighting"]),
			"skill_ids": PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike"]),
			"candidate_skill_ids": PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike", "kashimo_kyokyo_katsura"]),
			"ultimate_skill_id": "kashimo_phantom_beast_amber",
			"passive_skill_id": "kashimo_charge_separation",
		}
	)

func validate_core_skill_contract(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(validator, content_index, errors, [
		{
			"label": "formal[kashimo].raiken",
			"skill_id": "kashimo_raiken",
			"fields": {
				"display_name": "雷拳",
				"damage_kind": "physical",
				"power": 45,
				"accuracy": 100,
				"mp_cost": 12,
				"priority": 1,
				"combat_type_id": "thunder",
				"targeting": "enemy_active_slot",
				"effects_on_hit_ids": PackedStringArray(["kashimo_apply_negative_charge"]),
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo].charge",
			"skill_id": "kashimo_charge",
			"fields": {
				"display_name": "蓄电",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 8,
				"priority": 0,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["kashimo_apply_positive_charge"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo].feedback_strike",
			"skill_id": "kashimo_feedback_strike",
			"fields": {
				"display_name": "回授电击",
				"damage_kind": "special",
				"power": 30,
				"accuracy": 100,
				"mp_cost": 15,
				"priority": 0,
				"combat_type_id": "thunder",
				"targeting": "enemy_active_slot",
				"power_bonus_source": "effect_stack_sum",
				"effects_on_hit_ids": PackedStringArray(["kashimo_consume_positive_charges", "kashimo_consume_negative_charges"]),
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo].kyokyo",
			"skill_id": "kashimo_kyokyo_katsura",
			"fields": {
				"display_name": "弥虚葛笼",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 20,
				"priority": 2,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["kashimo_kyokyo_nullify"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo].amber",
			"skill_id": "kashimo_phantom_beast_amber",
			"fields": {
				"display_name": "幻兽琥珀",
				"damage_kind": "special",
				"power": 60,
				"accuracy": 100,
				"mp_cost": 35,
				"priority": 5,
				"combat_type_id": "thunder",
				"once_per_battle": true,
				"targeting": "enemy_active_slot",
				"is_domain_skill": false,
				"effects_on_cast_ids": PackedStringArray(["kashimo_amber_self_transform"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
	])

func validate_feedback_strike_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].feedback_strike"
	var skill_definition = validator._require_skill(content_index, errors, label, "kashimo_feedback_strike")
	if skill_definition == null:
		return
	validator._expect_string(errors, "%s power_bonus_source" % label, skill_definition.power_bonus_source, "effect_stack_sum")
	validator._expect_packed_string_array(errors, "%s power_bonus_self_effect_ids" % label, skill_definition.power_bonus_self_effect_ids, PackedStringArray(["kashimo_positive_charge_mark"]))
	validator._expect_packed_string_array(errors, "%s power_bonus_target_effect_ids" % label, skill_definition.power_bonus_target_effect_ids, PackedStringArray(["kashimo_negative_charge_mark"]))
	validator._expect_int(errors, "%s power_bonus_per_stack" % label, skill_definition.power_bonus_per_stack, 12)
func validate_kyokyo_contract(validator, content_index, errors: Array) -> void:
	var label := "formal[kashimo].kyokyo"
	var effect_definition = validator._require_effect(content_index, errors, label, "kashimo_kyokyo_nullify")
	if effect_definition == null:
		return
	validator._expect_string(errors, "%s effect.scope" % label, effect_definition.scope, "self")
	validator._expect_string(errors, "%s effect.duration_mode" % label, effect_definition.duration_mode, "turns")
	validator._expect_int(errors, "%s effect.duration" % label, effect_definition.duration, 3)
	validator._expect_string(errors, "%s effect.decrement_on" % label, effect_definition.decrement_on, "turn_end")
	validator._expect_string(errors, "%s effect.stacking" % label, effect_definition.stacking, "none")
	validator._expect_packed_string_array(errors, "%s effect.trigger_names" % label, effect_definition.trigger_names, PackedStringArray(["on_cast"]))
	var payload = validator._extract_single_payload(errors, label, "kashimo_kyokyo_nullify", effect_definition, RuleModPayloadScript, "rule_mod")
	validator._expect_payload_shape(
		errors,
		"%s effect" % label,
		payload,
		{
			"mod_kind": "nullify_field_accuracy",
			"mod_op": "set",
			"value": true,
			"scope": "self",
			"duration_mode": "turns",
			"duration": 3,
			"decrement_on": "turn_end",
			"stacking": "refresh",
			"priority": 10,
		}
	)
