extends RefCounted
class_name SukunaUltimateDomainContracts

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

func field_contracts() -> Array[Dictionary]:
	return [
		{
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
		},
	]
