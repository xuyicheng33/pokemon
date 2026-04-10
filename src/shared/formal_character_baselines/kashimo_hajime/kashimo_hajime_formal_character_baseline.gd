extends RefCounted
class_name KashimoHajimeFormalCharacterBaseline

const EffectContractsScript := preload("res://src/shared/formal_character_baselines/kashimo_hajime/kashimo_hajime_effect_contracts.gd")
const UltimateDomainContractsScript := preload("res://src/shared/formal_character_baselines/kashimo_hajime/kashimo_hajime_ultimate_domain_contracts.gd")

var _effect_contracts = EffectContractsScript.new()
var _ultimate_domain_contracts = UltimateDomainContractsScript.new()

func unit_contract() -> Dictionary:
	return {
		"label": "formal[kashimo_hajime].unit",
		"snapshot_label": "kashimo_hajime",
		"unit_id": "kashimo_hajime",
		"fields": {
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
		},
	}

func regular_skill_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[kashimo_hajime].raiken",
			"snapshot_label": "kashimo_raiken",
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
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["kashimo_apply_negative_charge"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo_hajime].charge",
			"snapshot_label": "kashimo_charge",
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
			"label": "formal[kashimo_hajime].feedback_strike",
			"snapshot_label": "kashimo_feedback_strike",
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
				"power_bonus_self_effect_ids": PackedStringArray(["kashimo_positive_charge_mark"]),
				"power_bonus_target_effect_ids": PackedStringArray(["kashimo_negative_charge_mark"]),
				"power_bonus_per_stack": 12,
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["kashimo_consume_positive_charges", "kashimo_consume_negative_charges"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo_hajime].kyokyo",
			"snapshot_label": "kashimo_kyokyo_katsura",
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
	]

func ultimate_skill_contract() -> Dictionary:
	return _ultimate_domain_contracts.ultimate_skill_contract()

func passive_skill_contract() -> Dictionary:
	return {
		"label": "formal[kashimo_hajime].charge_separation",
		"snapshot_label": "kashimo_charge_separation",
		"passive_skill_id": "kashimo_charge_separation",
		"fields": {
			"trigger_names": PackedStringArray(["on_enter"]),
			"effect_ids": PackedStringArray(["kashimo_thunder_resist", "kashimo_apply_water_leak_listeners"]),
		},
	}

func effect_contracts() -> Array[Dictionary]:
	return _effect_contracts.effect_contracts()

func field_contracts() -> Array[Dictionary]:
	return _ultimate_domain_contracts.field_contracts()
