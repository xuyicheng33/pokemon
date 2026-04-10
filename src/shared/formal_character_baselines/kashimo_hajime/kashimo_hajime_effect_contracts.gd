extends RefCounted
class_name KashimoHajimeEffectContracts

func effect_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[kashimo_hajime].negative_charge_mark",
			"snapshot_label": "kashimo_negative_charge_mark",
			"effect_id": "kashimo_negative_charge_mark",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 4,
				"decrement_on": "turn_end",
				"stacking": "stack",
				"max_stacks": 3,
				"persists_on_switch": false,
				"trigger_names": PackedStringArray(["turn_end"]),
			},
		},
		{
			"label": "formal[kashimo_hajime].positive_charge_mark",
			"snapshot_label": "kashimo_positive_charge_mark",
			"effect_id": "kashimo_positive_charge_mark",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 4,
				"decrement_on": "turn_end",
				"stacking": "stack",
				"max_stacks": 3,
				"persists_on_switch": false,
				"trigger_names": PackedStringArray(["turn_start"]),
			},
		},
		{
			"label": "formal[kashimo_hajime].kyokyo",
			"snapshot_label": "kashimo_kyokyo_nullify",
			"effect_id": "kashimo_kyokyo_nullify",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 3,
				"decrement_on": "turn_end",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		},
		{
			"label": "formal[kashimo_hajime].thunder_resist",
			"snapshot_label": "kashimo_thunder_resist",
			"effect_id": "kashimo_thunder_resist",
			"fields": {
				"display_name": "雷电抗性",
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_enter"]),
			},
		},
		{
			"label": "formal[kashimo_hajime].water_leak_listeners",
			"snapshot_label": "kashimo_apply_water_leak_listeners",
			"effect_id": "kashimo_apply_water_leak_listeners",
			"fields": {
				"scope": "self",
				"trigger_names": PackedStringArray(["on_enter"]),
			},
		},
		{
			"label": "formal[kashimo_hajime].water_leak_self",
			"snapshot_label": "kashimo_water_leak_self_listener",
			"effect_id": "kashimo_water_leak_self_listener",
			"fields": {
				"scope": "self",
				"trigger_names": PackedStringArray(["on_receive_action_hit"]),
				"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
				"required_incoming_combat_type_ids": PackedStringArray(["water"]),
			},
		},
		{
			"label": "formal[kashimo_hajime].water_leak_counter",
			"snapshot_label": "kashimo_water_leak_counter_listener",
			"effect_id": "kashimo_water_leak_counter_listener",
			"fields": {
				"scope": "action_actor",
				"trigger_names": PackedStringArray(["on_receive_action_hit"]),
				"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
				"required_incoming_combat_type_ids": PackedStringArray(["water"]),
			},
		},
		{
			"label": "formal[kashimo_hajime].amber_bleed",
			"snapshot_label": "kashimo_amber_bleed",
			"effect_id": "kashimo_amber_bleed",
			"fields": {
				"trigger_names": PackedStringArray(["turn_end"]),
				"persists_on_switch": true,
			},
		},
	]
