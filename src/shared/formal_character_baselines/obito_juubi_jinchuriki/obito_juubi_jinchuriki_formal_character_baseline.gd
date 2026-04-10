extends RefCounted
class_name ObitoJuubiJinchurikiFormalCharacterBaseline

const EffectContractsScript := preload("res://src/shared/formal_character_baselines/obito_juubi_jinchuriki/obito_juubi_jinchuriki_effect_contracts.gd")
const UltimateDomainContractsScript := preload("res://src/shared/formal_character_baselines/obito_juubi_jinchuriki/obito_juubi_jinchuriki_ultimate_domain_contracts.gd")

var _effect_contracts = EffectContractsScript.new()
var _ultimate_domain_contracts = UltimateDomainContractsScript.new()

func unit_contract() -> Dictionary:
	return {
		"label": "formal[obito_juubi_jinchuriki].unit",
		"snapshot_label": "obito_juubi_jinchuriki",
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
			"label": "formal[obito_juubi_jinchuriki].qiudao_jiaotu",
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
			"label": "formal[obito_juubi_jinchuriki].yinyang_dun",
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
			"label": "formal[obito_juubi_jinchuriki].qiudao_yu",
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
			"label": "formal[obito_juubi_jinchuriki].liudao_shizi_fenghuo",
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
	return _ultimate_domain_contracts.ultimate_skill_contract()

func passive_skill_contract() -> Dictionary:
	return {
		"label": "formal[obito_juubi_jinchuriki].xianren_zhili",
		"snapshot_label": "obito_xianren_zhili",
		"passive_skill_id": "obito_xianren_zhili",
		"fields": {
			"display_name": "仙人之力",
			"trigger_names": PackedStringArray(["turn_start"]),
			"effect_ids": PackedStringArray(["obito_xianren_zhili_heal"]),
		},
	}

func effect_contracts() -> Array[Dictionary]:
	return _effect_contracts.effect_contracts()

func field_contracts() -> Array[Dictionary]:
	return _ultimate_domain_contracts.field_contracts()
