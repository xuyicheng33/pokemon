extends RefCounted
class_name GojoSatoruEffectContracts

func effect_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[gojo_satoru].ao_mark",
			"snapshot_label": "gojo_ao_mark",
			"effect_id": "gojo_ao_mark",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 3,
				"decrement_on": "turn_end",
				"stacking": "refresh",
				"persists_on_switch": false,
			},
		},
		{
			"label": "formal[gojo_satoru].aka_mark",
			"snapshot_label": "gojo_aka_mark",
			"effect_id": "gojo_aka_mark",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 3,
				"decrement_on": "turn_end",
				"stacking": "refresh",
				"persists_on_switch": false,
			},
		},
		{
			"label": "formal[gojo_satoru].murasaki_burst",
			"snapshot_label": "gojo_murasaki_conditional_burst",
			"effect_id": "gojo_murasaki_conditional_burst",
			"fields": {
				"scope": "target",
				"trigger_names": PackedStringArray(["on_hit"]),
				"required_target_effects": PackedStringArray(["gojo_ao_mark", "gojo_aka_mark"]),
				"required_target_same_owner": true,
			},
		},
		{
			"label": "formal[gojo_satoru].domain_followup",
			"snapshot_label": "gojo_apply_domain_field",
			"effect_id": "gojo_apply_domain_field",
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
			"label": "formal[gojo_satoru].reverse_ritual.effect",
			"snapshot_label": "gojo_reverse_heal",
			"effect_id": "gojo_reverse_heal",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		},
		{
			"label": "formal[gojo_satoru].mugen.effect",
			"snapshot_label": "gojo_mugen_incoming_accuracy_down",
			"effect_id": "gojo_mugen_incoming_accuracy_down",
			"fields": {
				"trigger_names": PackedStringArray(["on_enter"]),
			},
		},
	]
