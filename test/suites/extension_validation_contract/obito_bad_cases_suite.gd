extends "res://test/suites/extension_validation_contract/base.gd"

func test_formal_obito_validator_heal_block_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[obito_juubi_jinchuriki].heal_block payload.value mismatch: expected 0.0 got 1.0",
		"obito formal validator should fail-fast when heal-block payload drifts",
		func(content_index):
			var heal_block_effect = content_index.effects.get("obito_qiudao_jiaotu_heal_block_rule_mod", null)
			if heal_block_effect == null or heal_block_effect.payloads.is_empty():
				return "missing obito_qiudao_jiaotu_heal_block_rule_mod payload"
			heal_block_effect.payloads[0].value = 1.0
			return ""
	)

func test_formal_obito_validator_heal_block_surface_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[obito_juubi_jinchuriki].heal_block rule_mod persists_on_switch mismatch",
		"obito formal validator should fail-fast when heal-block surface drifts",
		func(content_index):
			var heal_block_effect = content_index.effects.get("obito_qiudao_jiaotu_heal_block_rule_mod", null)
			if heal_block_effect == null:
				return "missing obito_qiudao_jiaotu_heal_block_rule_mod"
			heal_block_effect.persists_on_switch = false
			return ""
	)

func test_formal_obito_validator_execute_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[obito_juubi_jinchuriki].qiudao_yu execute_required_total_stacks mismatch: expected 5 got 4",
		"obito formal validator should fail-fast when execute stack threshold drifts",
		func(content_index):
			var qiudaoyu = content_index.skills.get("obito_qiudao_yu", null)
			if qiudaoyu == null:
				return "missing obito_qiudao_yu"
			qiudaoyu.execute_required_total_stacks = 4
			return ""
	)

func test_formal_obito_validator_yinyang_guard_surface_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[obito_juubi_jinchuriki].yinyang_dun guard trigger_names mismatch",
		"obito formal validator should fail-fast when yinyang guard surface drifts",
		func(content_index):
			var guard_effect = content_index.effects.get("obito_yinyang_dun_guard_rule_mod", null)
			if guard_effect == null:
				return "missing obito_yinyang_dun_guard_rule_mod"
			guard_effect.trigger_names = PackedStringArray(["on_hit"])
			return ""
	)

func test_formal_obito_validator_yinyang_listener_surface_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[obito_juubi_jinchuriki].yinyang_dun listener_state trigger_names mismatch",
		"obito formal validator should fail-fast when yinyang listener surface drifts",
		func(content_index):
			var listener_state = content_index.effects.get("obito_yinyang_dun_guard_stack_listener_state", null)
			if listener_state == null:
				return "missing obito_yinyang_dun_guard_stack_listener_state"
			listener_state.trigger_names = PackedStringArray(["on_hit"])
			return ""
	)

func test_formal_obito_validator_ultimate_segments_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[obito_juubi_jinchuriki].shiwei_weishouyu damage_segments[1].repeat_count mismatch: expected 8 got 7",
		"obito formal validator should fail-fast when ultimate segment count drifts",
		func(content_index):
			var ultimate = content_index.skills.get("obito_shiwei_weishouyu", null)
			if ultimate == null or ultimate.damage_segments.size() != 2:
				return "missing obito_shiwei_weishouyu damage_segments"
			ultimate.damage_segments[1].repeat_count = 7
			return ""
	)
