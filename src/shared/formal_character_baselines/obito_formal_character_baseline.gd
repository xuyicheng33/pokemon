extends RefCounted
class_name ObitoFormalCharacterBaseline

func unit_contract() -> Dictionary:
	return {
		"label": "formal[obito].unit",
		"snapshot_label": "obito",
		"unit_id": "obito_juubi_jinchuriki",
		"fields": {
			"display_name": "宇智波带土·十尾人柱力",
			"base_hp": 128,
			"base_attack": 58,
			"base_defense": 78,
			"base_sp_attack": 88,
			"base_sp_defense": 80,
			"base_speed": 64,
			"max_mp": 100,
			"init_mp": 48,
			"regen_per_turn": 12,
			"ultimate_points_required": 3,
			"ultimate_points_cap": 3,
			"ultimate_point_gain_on_regular_skill_cast": 1,
			"combat_type_ids": PackedStringArray(["light", "dark"]),
			"skill_ids": PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_qiudao_yu"]),
			"candidate_skill_ids": PackedStringArray(["obito_qiudao_jiaotu", "obito_yinyang_dun", "obito_qiudao_yu", "obito_liudao_shizi_fenghuo"]),
			"ultimate_skill_id": "obito_shiwei_weishouyu",
			"passive_skill_id": "obito_xianren_zhili",
			"passive_item_id": "",
		},
	}

func regular_skill_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[obito].qiudao_jiaotu",
			"snapshot_label": "obito_qiudao_jiaotu",
			"skill_id": "obito_qiudao_jiaotu",
			"fields": {
				"display_name": "求道焦土",
				"damage_kind": "special",
				"power": 42,
				"accuracy": 100,
				"mp_cost": 10,
				"priority": 0,
				"combat_type_id": "dark",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["obito_qiudao_jiaotu_heal_block_apply", "obito_qiudao_jiaotu_heal_block_rule_mod"]),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[obito].yinyang_dun",
			"snapshot_label": "obito_yinyang_dun",
			"skill_id": "obito_yinyang_dun",
			"fields": {
				"display_name": "阴阳遁",
				"damage_kind": "none",
				"power": 0,
				"accuracy": 100,
				"mp_cost": 16,
				"priority": 2,
				"combat_type_id": "",
				"targeting": "self",
				"effects_on_cast_ids": PackedStringArray(["obito_yinyang_dun_boost_and_charge", "obito_yinyang_dun_guard_rule_mod", "obito_yinyang_dun_guard_stack_listener"]),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[obito].qiudao_yu",
			"snapshot_label": "obito_qiudao_yu",
			"skill_id": "obito_qiudao_yu",
			"fields": {
				"display_name": "求道玉",
				"damage_kind": "special",
				"power": 24,
				"accuracy": 100,
				"mp_cost": 18,
				"priority": 0,
				"combat_type_id": "light",
				"power_bonus_source": "effect_stack_sum",
				"power_bonus_self_effect_ids": PackedStringArray(["obito_yinyang_zhili"]),
				"power_bonus_target_effect_ids": PackedStringArray(),
				"power_bonus_per_stack": 12,
				"targeting": "enemy_active_slot",
				"execute_target_hp_ratio_lte": 0.3,
				"execute_required_total_stacks": 5,
				"execute_self_effect_ids": PackedStringArray(["obito_yinyang_zhili"]),
				"execute_target_effect_ids": PackedStringArray(),
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(["obito_qiudao_yu_clear_yinyang"]),
				"effects_on_miss_ids": PackedStringArray(["obito_qiudao_yu_clear_yinyang"]),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
		{
			"label": "formal[obito].liudao_shizi_fenghuo",
			"snapshot_label": "obito_liudao_shizi_fenghuo",
			"skill_id": "obito_liudao_shizi_fenghuo",
			"fields": {
				"display_name": "六道十字奉火",
				"damage_kind": "special",
				"power": 62,
				"accuracy": 90,
				"mp_cost": 24,
				"priority": -1,
				"combat_type_id": "fire",
				"targeting": "enemy_active_slot",
				"effects_on_cast_ids": PackedStringArray(),
				"effects_on_hit_ids": PackedStringArray(),
				"effects_on_miss_ids": PackedStringArray(),
				"effects_on_kill_ids": PackedStringArray(),
			},
		},
	]

func ultimate_skill_contract() -> Dictionary:
	return {
		"label": "formal[obito].shiwei_weishouyu",
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

func snapshot_skill_contracts() -> Array[Dictionary]:
	var descriptors := regular_skill_contracts()
	descriptors.append(ultimate_skill_contract())
	return descriptors

func passive_skill_contract() -> Dictionary:
	return {
		"label": "formal[obito].xianren_zhili",
		"snapshot_label": "obito_xianren_zhili",
		"passive_skill_id": "obito_xianren_zhili",
		"fields": {
			"display_name": "仙人之力",
			"trigger_names": PackedStringArray(["turn_start"]),
			"effect_ids": PackedStringArray(["obito_xianren_zhili_heal"]),
		},
	}

func passive_skill_contracts() -> Array[Dictionary]:
	return [passive_skill_contract()]

func effect_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[obito].xianren_zhili.effect",
			"snapshot_label": "obito_xianren_zhili_heal",
			"effect_id": "obito_xianren_zhili_heal",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["turn_start"]),
			},
		},
		{
			"label": "formal[obito].yinyang_zhili",
			"snapshot_label": "obito_yinyang_zhili",
			"effect_id": "obito_yinyang_zhili",
			"fields": {
				"display_name": "阴阳之力",
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "stack",
				"max_stacks": 5,
				"trigger_names": PackedStringArray(),
				"persists_on_switch": false,
			},
		},
		{
			"label": "formal[obito].heal_block.apply",
			"snapshot_label": "obito_qiudao_jiaotu_heal_block_apply",
			"effect_id": "obito_qiudao_jiaotu_heal_block_apply",
			"fields": {
				"scope": "target",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_hit"]),
			},
		},
		{
			"label": "formal[obito].heal_block.mark",
			"snapshot_label": "obito_qiudao_jiaotu_heal_block_mark",
			"effect_id": "obito_qiudao_jiaotu_heal_block_mark",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 2,
				"decrement_on": "turn_end",
				"stacking": "refresh",
				"trigger_names": PackedStringArray(),
				"persists_on_switch": true,
			},
		},
		{
			"label": "formal[obito].heal_block.rule_mod",
			"snapshot_label": "obito_qiudao_jiaotu_heal_block_rule_mod",
			"effect_id": "obito_qiudao_jiaotu_heal_block_rule_mod",
			"fields": {
				"scope": "target",
				"duration_mode": "turns",
				"duration": 2,
				"decrement_on": "turn_end",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_hit"]),
				"persists_on_switch": true,
			},
		},
		{
			"label": "formal[obito].yinyang_dun.guard",
			"snapshot_label": "obito_yinyang_dun_guard_rule_mod",
			"effect_id": "obito_yinyang_dun_guard_rule_mod",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 1,
				"decrement_on": "turn_end",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		},
		{
			"label": "formal[obito].yinyang_dun.boost",
			"snapshot_label": "obito_yinyang_dun_boost_and_charge",
			"effect_id": "obito_yinyang_dun_boost_and_charge",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		},
		{
			"label": "formal[obito].yinyang_dun.listener_apply",
			"snapshot_label": "obito_yinyang_dun_guard_stack_listener",
			"effect_id": "obito_yinyang_dun_guard_stack_listener",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_cast"]),
			},
		},
		{
			"label": "formal[obito].yinyang_dun.listener_state",
			"snapshot_label": "obito_yinyang_dun_guard_stack_listener_state",
			"effect_id": "obito_yinyang_dun_guard_stack_listener_state",
			"fields": {
				"scope": "self",
				"duration_mode": "turns",
				"duration": 1,
				"decrement_on": "turn_end",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_receive_action_damage_segment"]),
				"required_incoming_command_types": PackedStringArray(["skill", "ultimate"]),
				"persists_on_switch": false,
			},
		},
		{
			"label": "formal[obito].qiudao_yu.clear",
			"snapshot_label": "obito_qiudao_yu_clear_yinyang",
			"effect_id": "obito_qiudao_yu_clear_yinyang",
			"fields": {
				"scope": "self",
				"duration_mode": "permanent",
				"stacking": "none",
				"trigger_names": PackedStringArray(["on_hit", "on_miss"]),
			},
		},
	]

func field_contracts() -> Array[Dictionary]:
	return []
