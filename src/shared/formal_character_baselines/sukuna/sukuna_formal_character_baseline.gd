extends RefCounted
class_name SukunaFormalCharacterBaseline

const EffectContractsScript := preload("res://src/shared/formal_character_baselines/sukuna/sukuna_effect_contracts.gd")
const UltimateDomainContractsScript := preload("res://src/shared/formal_character_baselines/sukuna/sukuna_ultimate_domain_contracts.gd")

var _effect_contracts = EffectContractsScript.new()
var _ultimate_domain_contracts = UltimateDomainContractsScript.new()

func unit_contract() -> Dictionary:
	return {
		"label": "formal[sukuna].unit",
		"snapshot_label": "sukuna",
		"unit_id": "sukuna",
		"fields": {
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
		},
	}

func regular_skill_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[sukuna].kai",
			"snapshot_label": "sukuna_kai",
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
			"snapshot_label": "sukuna_hatsu",
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
			"snapshot_label": "sukuna_hiraku",
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
			"snapshot_label": "sukuna_reverse_ritual",
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
	]

func ultimate_skill_contract() -> Dictionary:
	return _ultimate_domain_contracts.ultimate_skill_contract()

func passive_skill_contract() -> Dictionary:
	return {
		"label": "formal[sukuna].teach_love",
		"snapshot_label": "sukuna_teach_love",
		"passive_skill_id": "sukuna_teach_love",
		"fields": {
			"trigger_names": PackedStringArray(["on_matchup_changed"]),
			"effect_ids": PackedStringArray(["sukuna_refresh_love_regen"]),
		},
	}

func effect_contracts() -> Array[Dictionary]:
	return _effect_contracts.effect_contracts()

func field_contracts() -> Array[Dictionary]:
	return _ultimate_domain_contracts.field_contracts()
