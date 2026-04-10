extends RefCounted
class_name SukunaEffectContracts

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
