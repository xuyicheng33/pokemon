extends RefCounted
class_name KashimoFormalCharacterBaseline

func unit_contract() -> Dictionary:
	return {
		"label": "formal[kashimo].unit",
		"snapshot_label": "kashimo",
		"unit_id": "kashimo_hajime",
		"fields": {
			"display_name": "鹿紫云一",
			"base_hp": 118,
			"base_attack": 82,
			"base_defense": 58,
			"base_sp_attack": 72,
			"base_sp_defense": 54,
			"base_speed": 90,
			"max_mp": 100,
			"init_mp": 40,
			"regen_per_turn": 10,
			"ultimate_points_required": 3,
			"ultimate_points_cap": 3,
			"ultimate_point_gain_on_regular_skill_cast": 1,
			"combat_type_ids": PackedStringArray(["thunder", "fighting"]),
			"skill_ids": PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike"]),
			"candidate_skill_ids": PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_feedback_strike", "kashimo_kyokyo_katsura"]),
			"ultimate_skill_id": "kashimo_phantom_beast_amber",
			"passive_skill_id": "kashimo_charge_separation",
		},
	}

func regular_skill_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[kashimo].raiken",
			"snapshot_label": "kashimo_raiken",
			"skill_id": "kashimo_raiken",
			"fields": {
				"display_name": "雷拳",
				"damage_kind": "physical",
				"power": 45,
				"accuracy": 100,
				"mp_cost": 12,
				"priority": 1,
				"combat_type_id": "thunder",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["kashimo_apply_negative_charge"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo].charge",
			"snapshot_label": "kashimo_charge",
			"skill_id": "kashimo_charge",
			"fields": {
				"display_name": "蓄电",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 8,
				"priority": 0,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["kashimo_apply_positive_charge"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo].feedback_strike",
			"snapshot_label": "kashimo_feedback_strike",
			"skill_id": "kashimo_feedback_strike",
			"fields": {
				"display_name": "回授电击",
				"damage_kind": "special",
				"power": 30,
				"accuracy": 100,
				"mp_cost": 15,
				"priority": 0,
				"combat_type_id": "thunder",
				"targeting": "enemy_active_slot",
				"power_bonus_source": "effect_stack_sum",
				"power_bonus_self_effect_ids": PackedStringArray(["kashimo_positive_charge_mark"]),
				"power_bonus_target_effect_ids": PackedStringArray(["kashimo_negative_charge_mark"]),
				"power_bonus_per_stack": 12,
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["kashimo_consume_positive_charges", "kashimo_consume_negative_charges"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[kashimo].kyokyo",
			"snapshot_label": "kashimo_kyokyo_katsura",
			"skill_id": "kashimo_kyokyo_katsura",
			"fields": {
				"display_name": "弥虚葛笼",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 20,
				"priority": 2,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["kashimo_kyokyo_nullify"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
	]

func ultimate_skill_contract() -> Dictionary:
	return {
		"label": "formal[kashimo].amber",
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

func snapshot_skill_contracts() -> Array[Dictionary]:
	var descriptors := regular_skill_contracts()
	descriptors.append(ultimate_skill_contract())
	return descriptors

func passive_skill_contract() -> Dictionary:
	return {
		"label": "formal[kashimo].charge_separation",
		"snapshot_label": "kashimo_charge_separation",
		"passive_skill_id": "kashimo_charge_separation",
		"fields": {
			"trigger_names": PackedStringArray(["on_enter"]),
			"effect_ids": PackedStringArray(["kashimo_thunder_resist", "kashimo_apply_water_leak_listeners"]),
		},
	}

func passive_skill_contracts() -> Array[Dictionary]:
	return [passive_skill_contract()]

func effect_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[kashimo].negative_charge_mark",
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
			"label": "formal[kashimo].positive_charge_mark",
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
			"label": "formal[kashimo].kyokyo",
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
			"label": "formal[kashimo].thunder_resist",
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
			"label": "formal[kashimo].water_leak_listeners",
			"snapshot_label": "kashimo_apply_water_leak_listeners",
			"effect_id": "kashimo_apply_water_leak_listeners",
			"fields": {
				"scope": "self",
				"trigger_names": PackedStringArray(["on_enter"]),
			},
		},
		{
			"label": "formal[kashimo].water_leak_self",
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
			"label": "formal[kashimo].water_leak_counter",
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
			"label": "formal[kashimo].amber_bleed",
			"snapshot_label": "kashimo_amber_bleed",
			"effect_id": "kashimo_amber_bleed",
			"fields": {
				"trigger_names": PackedStringArray(["turn_end"]),
				"persists_on_switch": true,
			},
		},
	]

func field_contracts() -> Array[Dictionary]:
	return []
