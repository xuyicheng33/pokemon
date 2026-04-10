extends RefCounted
class_name GojoSatoruUltimateDomainContracts

func ultimate_skill_contract() -> Dictionary:
	return {
		"label": "formal[gojo_satoru].unlimited_void",
		"snapshot_label": "gojo_unlimited_void",
		"skill_id": "gojo_unlimited_void",
		"fields": {
			"display_name": "无量空处",
			"damage_kind": "special",
			"power": 48,
			"accuracy": 100,
			"mp_cost": 50,
			"priority": 5,
			"combat_type_id": "space",
			"targeting": "enemy_active_slot",
			"is_domain_skill": true,
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(["gojo_apply_domain_field"]),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		},
	}

func field_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[gojo_satoru].domain_field",
			"snapshot_label": "gojo_unlimited_void_field",
			"field_id": "gojo_unlimited_void_field",
			"fields": {
				"field_kind": "domain",
				"effect_ids": PackedStringArray(["gojo_domain_cast_buff"]),
				"on_expire_effect_ids": PackedStringArray(["gojo_domain_buff_remove"]),
				"on_break_effect_ids": PackedStringArray(["gojo_domain_buff_remove"]),
				"creator_accuracy_override": 100,
			},
		},
	]
