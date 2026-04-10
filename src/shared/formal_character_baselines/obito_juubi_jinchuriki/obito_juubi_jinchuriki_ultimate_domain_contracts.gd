extends RefCounted
class_name ObitoJuubiJinchurikiUltimateDomainContracts

func ultimate_skill_contract() -> Dictionary:
	return {
		"label": "formal[obito_juubi_jinchuriki].shiwei_weishouyu",
		"snapshot_label": "obito_shiwei_weishouyu",
		"skill_id": "obito_shiwei_weishouyu",
		"fields": {
			"display_name": "十尾尾兽玉",
			"damage_kind": "special",
			"power": 0,
			"accuracy": 100,
			"mp_cost": 50,
			"priority": 5,
			"combat_type_id": "",
			"targeting": "enemy_active_slot",
			"effects_on_cast_ids": PackedStringArray(),
			"effects_on_hit_ids": PackedStringArray(),
			"effects_on_miss_ids": PackedStringArray(),
			"effects_on_kill_ids": PackedStringArray(),
		},
	}

func field_contracts() -> Array[Dictionary]:
	return []
