extends "res://test/suites/extension_validation_contract/base.gd"

func test_formal_gojo_validator_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[gojo_satoru].ao power mismatch: expected 44 got 45",
		"gojo formal validator should fail-fast when ao power drifts",
		func(content_index):
			var gojo_ao = content_index.skills.get("gojo_ao", null)
			if gojo_ao == null:
				return "missing gojo_ao"
			gojo_ao.power = 45
			return ""
	)

func test_formal_gojo_validator_reverse_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[gojo_satoru].reverse_ritual mp_cost mismatch: expected 14 got 15",
		"gojo formal validator should fail-fast when reverse_ritual mp_cost drifts",
		func(content_index):
			var gojo_reverse_ritual = content_index.skills.get("gojo_reverse_ritual", null)
			if gojo_reverse_ritual == null:
				return "missing gojo_reverse_ritual"
			gojo_reverse_ritual.mp_cost = 15
			return ""
	)

func test_formal_gojo_validator_murasaki_cleanup_bad_case_contract() -> void:
	_run_validator_bad_case(
		'formal[gojo_satoru].murasaki_burst payload[1].effect_definition_id mismatch: expected "gojo_ao_mark" got "gojo_aka_mark"',
		"gojo formal validator should fail-fast when murasaki cleanup payload drifts",
		func(content_index):
			var murasaki_burst = content_index.effects.get("gojo_murasaki_conditional_burst", null)
			if murasaki_burst == null or murasaki_burst.payloads.size() < 3:
				return "missing gojo_murasaki_conditional_burst cleanup payloads"
			murasaki_burst.payloads[1].effect_definition_id = "gojo_aka_mark"
			return ""
	)

func test_formal_gojo_validator_action_lock_surface_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[gojo_satoru].domain_buff_contract action_lock scope mismatch: expected target got self",
		"gojo formal validator should fail-fast when action_lock surface drifts",
		func(content_index):
			var action_lock = content_index.effects.get("gojo_domain_action_lock", null)
			if action_lock == null:
				return "missing gojo_domain_action_lock"
			action_lock.scope = "self"
			return ""
	)

func test_formal_gojo_validator_action_lock_stacking_bad_case_contract() -> void:
	_run_validator_bad_case(
		'formal[gojo_satoru].domain_buff_contract action_lock.stacking mismatch: expected "replace" got "refresh"',
		"gojo formal validator should fail-fast when action_lock stacking drifts",
		func(content_index):
			var action_lock = content_index.effects.get("gojo_domain_action_lock", null)
			if action_lock == null or action_lock.payloads.is_empty():
				return "missing gojo_domain_action_lock payload"
			action_lock.payloads[0].stacking = "refresh"
			return ""
	)
