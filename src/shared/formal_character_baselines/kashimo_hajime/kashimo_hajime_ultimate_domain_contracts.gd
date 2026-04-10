extends RefCounted
class_name KashimoHajimeUltimateDomainContracts

func ultimate_skill_contract() -> Dictionary:
	return {
		"label": "formal[kashimo_hajime].amber",
		"snapshot_label": "kashimo_phantom_beast_amber",
		"skill_id": "kashimo_phantom_beast_amber",
		"fields": {
			"display_name": "幻兽琥珀",
			"damage_kind": "special",
			"power": 60,
			"accuracy": 100,
			"mp_cost": 35,
			"priority": 5,
			"combat_type_id": "thunder",
			"targeting": "enemy_active_slot",
			"once_per_battle": true,
			"effects_on_cast_ids": PackedStringArray(["kashimo_amber_self_transform"]),
			"effects_on_hit_ids": PackedStringArray(),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		},
	}

func field_contracts() -> Array[Dictionary]:
	return []
