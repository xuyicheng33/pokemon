extends RefCounted
class_name SukunaFormalCharacterBaseline

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
	return {
		"label": "formal[sukuna].fukuma_mizushi",
		"snapshot_label": "sukuna_fukuma_mizushi",
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
	}

func snapshot_skill_contracts() -> Array[Dictionary]:
	var descriptors := regular_skill_contracts()
	descriptors.append(ultimate_skill_contract())
	return descriptors

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

func passive_skill_contracts() -> Array[Dictionary]:
	return [passive_skill_contract()]

func effect_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[sukuna].kamado.mark",
			"snapshot_label": "sukuna_kamado_mark",
			"effect_id": "sukuna_kamado_mark",
			"fields": {
				"duration_mode": "turns",
				"duration": 3,
				"decrement_on": "turn_end",
				"stacking": "stack",
				"max_stacks": 3,
				"trigger_names": PackedStringArray(["on_exit"]),
				"on_expire_effect_ids": PackedStringArray(["sukuna_kamado_explode"]),
				"persists_on_switch": false,
			},
		},
		{
			"label": "formal[sukuna].domain.apply",
			"snapshot_label": "sukuna_apply_domain_field",
			"effect_id": "sukuna_apply_domain_field",
			"fields": {
				"scope": "field",
				"duration_mode": "turns",
				"duration": 3,
				"decrement_on": "turn_end",
				"stacking": "replace",
				"trigger_names": PackedStringArray(["on_hit"]),
			},
		},
		{
			"label": "formal[sukuna].reverse_ritual.effect",
			"snapshot_label": "sukuna_reverse_heal",
			"effect_id": "sukuna_reverse_heal",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		},
	]

func domain_field_contract() -> Dictionary:
	return {
		"label": "formal[sukuna].domain_field",
		"snapshot_label": "sukuna_malevolent_shrine_field",
		"field_id": "sukuna_malevolent_shrine_field",
		"fields": {
			"field_kind": "domain",
			"effect_ids": PackedStringArray(["sukuna_domain_cast_buff"]),
			"on_expire_effect_ids": PackedStringArray(["sukuna_domain_buff_remove", "sukuna_domain_expire_burst"]),
			"on_break_effect_ids": PackedStringArray(["sukuna_domain_buff_remove"]),
			"creator_accuracy_override": 100,
		},
	}

func field_contracts() -> Array[Dictionary]:
	return [domain_field_contract()]
