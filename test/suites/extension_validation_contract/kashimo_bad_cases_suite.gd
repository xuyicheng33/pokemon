extends "res://test/suites/extension_validation_contract/base.gd"

func test_formal_kashimo_validator_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[kashimo_hajime].charge mp_cost mismatch: expected 8 got 9",
		"kashimo formal validator should fail-fast when charge mp_cost drifts",
		func(content_index):
			var kashimo_charge = content_index.skills.get("kashimo_charge", null)
			if kashimo_charge == null:
				return "missing kashimo_charge"
			kashimo_charge.mp_cost = 9
			return ""
	)

func test_formal_kashimo_validator_kyokyo_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[kashimo_hajime].kyokyo priority mismatch: expected 2 got 1",
		"kashimo formal validator should fail-fast when kyokyo priority drifts",
		func(content_index):
			var kyokyo = content_index.skills.get("kashimo_kyokyo_katsura", null)
			if kyokyo == null:
				return "missing kashimo_kyokyo_katsura"
			kyokyo.priority = 1
			return ""
	)

func test_formal_kashimo_validator_charge_mark_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[kashimo_hajime].negative_charge_mark max_stacks mismatch: expected 3 got 2",
		"kashimo formal validator should fail-fast when negative charge stack cap drifts",
		func(content_index):
			var negative_mark = content_index.effects.get("kashimo_negative_charge_mark", null)
			if negative_mark == null:
				return "missing kashimo_negative_charge_mark"
			negative_mark.max_stacks = 2
			return ""
	)

func test_formal_kashimo_validator_thunder_resist_surface_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[kashimo_hajime].thunder_resist scope mismatch: expected self got target",
		"kashimo formal validator should fail-fast when thunder_resist surface drifts",
		func(content_index):
			var thunder_resist = content_index.effects.get("kashimo_thunder_resist", null)
			if thunder_resist == null:
				return "missing kashimo_thunder_resist"
			thunder_resist.scope = "target"
			return ""
	)

func test_formal_kashimo_validator_water_leak_counter_fixed_damage_bad_case_contract() -> void:
	_run_validator_bad_case(
		"formal[kashimo_hajime].water_leak_counter use_formula mismatch: expected false got true",
		"kashimo formal validator should fail-fast when water leak counter stops being fixed damage",
		func(content_index):
			var water_counter = content_index.effects.get("kashimo_water_leak_counter_listener", null)
			if water_counter == null or water_counter.payloads.is_empty():
				return "missing kashimo_water_leak_counter_listener payload"
			water_counter.payloads[0].use_formula = true
			return ""
	)
