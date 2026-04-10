extends RefCounted
class_name GojoSatoruFormalCharacterBaseline

const EffectContractsScript := preload("res://src/shared/formal_character_baselines/gojo_satoru/gojo_satoru_effect_contracts.gd")
const UltimateDomainContractsScript := preload("res://src/shared/formal_character_baselines/gojo_satoru/gojo_satoru_ultimate_domain_contracts.gd")

var _effect_contracts = EffectContractsScript.new()
var _ultimate_domain_contracts = UltimateDomainContractsScript.new()

func unit_contract() -> Dictionary:
	return {
		"label": "formal[gojo_satoru].unit",
		"snapshot_label": "gojo_satoru",
		"unit_id": "gojo_satoru",
		"fields": {
			"display_name": "五条悟",
			"base_hp": 124,
			"base_attack": 56,
			"base_defense": 60,
			"base_sp_attack": 88,
			"base_sp_defense": 68,
			"base_speed": 86,
			"max_mp": 100,
			"init_mp": 50,
			"regen_per_turn": 14,
			"ultimate_points_required": 3,
			"ultimate_points_cap": 3,
			"ultimate_point_gain_on_regular_skill_cast": 1,
			"combat_type_ids": PackedStringArray(["space", "psychic"]),
			"skill_ids": PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"]),
			"candidate_skill_ids": PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"]),
			"ultimate_skill_id": "gojo_unlimited_void",
			"passive_skill_id": "gojo_mugen",
		},
	}

func regular_skill_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[gojo_satoru].ao",
			"snapshot_label": "gojo_ao",
			"skill_id": "gojo_ao",
			"fields": {
				"display_name": "苍",
				"damage_kind": "special",
				"power": 44,
				"accuracy": 95,
				"mp_cost": 14,
				"priority": 0,
				"combat_type_id": "space",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["gojo_ao_speed_up", "gojo_ao_mark_apply"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[gojo_satoru].aka",
			"snapshot_label": "gojo_aka",
			"skill_id": "gojo_aka",
			"fields": {
				"display_name": "赫",
				"damage_kind": "special",
				"power": 44,
				"accuracy": 95,
				"mp_cost": 14,
				"priority": 0,
				"combat_type_id": "psychic",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["gojo_aka_slow_down", "gojo_aka_mark_apply"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[gojo_satoru].murasaki",
			"snapshot_label": "gojo_murasaki",
			"skill_id": "gojo_murasaki",
			"fields": {
				"display_name": "茈",
				"damage_kind": "special",
				"power": 64,
				"accuracy": 90,
				"mp_cost": 24,
				"priority": -1,
				"combat_type_id": "space",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["gojo_murasaki_conditional_burst"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[gojo_satoru].reverse_ritual",
			"snapshot_label": "gojo_reverse_ritual",
			"skill_id": "gojo_reverse_ritual",
			"fields": {
				"display_name": "反转术式",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 14,
				"priority": 0,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["gojo_reverse_heal"]),
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
		"label": "formal[gojo_satoru].mugen",
		"snapshot_label": "gojo_mugen",
		"passive_skill_id": "gojo_mugen",
		"fields": {
			"trigger_names": PackedStringArray(["on_enter"]),
			"effect_ids": PackedStringArray(["gojo_mugen_incoming_accuracy_down"]),
		},
	}

func effect_contracts() -> Array[Dictionary]:
	return _effect_contracts.effect_contracts()

func field_contracts() -> Array[Dictionary]:
	return _ultimate_domain_contracts.field_contracts()
