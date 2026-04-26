extends "res://test/suites/extension_validation_contract/base.gd"

func test_formal_sukuna_validator_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[sukuna].kai priority mismatch: expected 1 got 0",
		"sukuna formal validator should fail-fast when kai priority drifts",
		func(content_index):
			var sukuna_kai = content_index.skills.get("sukuna_kai", null)
			if sukuna_kai == null:
				return "missing sukuna_kai"
			sukuna_kai.priority = 0
			return ""
	)

func test_formal_sukuna_validator_reverse_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[sukuna].reverse_ritual mp_cost mismatch: expected 14 got 15",
		"sukuna formal validator should fail-fast when reverse_ritual mp_cost drifts",
		func(content_index):
			var sukuna_reverse_ritual = content_index.skills.get("sukuna_reverse_ritual", null)
			if sukuna_reverse_ritual == null:
				return "missing sukuna_reverse_ritual"
			sukuna_reverse_ritual.mp_cost = 15
			return ""
	)

func test_formal_sukuna_validator_regen_surface_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[sukuna].teach_love effect stacking mismatch: expected none got refresh",
		"sukuna formal validator should fail-fast when regen surface drifts",
		func(content_index):
			var regen_effect = content_index.effects.get("sukuna_refresh_love_regen", null)
			if regen_effect == null:
				return "missing sukuna_refresh_love_regen"
			regen_effect.stacking = "refresh"
			return ""
	)
