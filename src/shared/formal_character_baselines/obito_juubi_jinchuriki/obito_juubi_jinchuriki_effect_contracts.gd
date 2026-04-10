extends RefCounted
class_name ObitoJuubiJinchurikiEffectContracts

func effect_contracts() -> Array[Dictionary]:
	return [
		{
			"label": "formal[obito_juubi_jinchuriki].xianren_zhili.effect",
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
			"label": "formal[obito_juubi_jinchuriki].yinyang_zhili",
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
			"label": "formal[obito_juubi_jinchuriki].heal_block.apply",
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
			"label": "formal[obito_juubi_jinchuriki].heal_block.mark",
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
			"label": "formal[obito_juubi_jinchuriki].heal_block.rule_mod",
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
			"label": "formal[obito_juubi_jinchuriki].yinyang_dun.guard",
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
			"label": "formal[obito_juubi_jinchuriki].yinyang_dun.boost",
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
			"label": "formal[obito_juubi_jinchuriki].yinyang_dun.listener_apply",
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
			"label": "formal[obito_juubi_jinchuriki].yinyang_dun.listener_state",
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
			"label": "formal[obito_juubi_jinchuriki].qiudao_yu.clear",
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
