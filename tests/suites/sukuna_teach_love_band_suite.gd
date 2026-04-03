extends RefCounted
class_name SukunaTeachLoveBandSuite

const SukunaSetupRegenTestSupportScript := preload("res://tests/support/sukuna_setup_regen_test_support.gd")

const SUKUNA_BST_TOTAL := 586

var _support = SukunaSetupRegenTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("sukuna_teach_love_band_table_contract", failures, Callable(self, "_test_sukuna_teach_love_band_table_contract").bind(harness))

func _test_sukuna_teach_love_band_table_contract(harness) -> Dictionary:
	var cases: Array[Dictionary] = [
		{"gap": 0, "expected_bonus": 9},
		{"gap": 20, "expected_bonus": 9},
		{"gap": 21, "expected_bonus": 8},
		{"gap": 40, "expected_bonus": 8},
		{"gap": 41, "expected_bonus": 7},
		{"gap": 70, "expected_bonus": 7},
		{"gap": 71, "expected_bonus": 6},
		{"gap": 110, "expected_bonus": 6},
		{"gap": 111, "expected_bonus": 5},
		{"gap": 160, "expected_bonus": 5},
		{"gap": 161, "expected_bonus": 0},
	]
	for index in range(cases.size()):
		var case_data: Dictionary = cases[index]
		var result: Dictionary = _run_gap_case(harness, int(case_data["gap"]), int(case_data["expected_bonus"]), 8200 + index)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()

func _run_gap_case(harness, gap: int, expected_bonus: int, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var opponent_definition = content_index.units.get("sample_tidekit", null)
	if opponent_definition == null:
		return harness.fail_result("missing sample_tidekit unit definition for gap=%d" % gap)
	_override_unit_total_for_gap(opponent_definition, gap)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory), seed)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var opponent_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or opponent_unit == null:
		return harness.fail_result("missing active units for gap=%d" % gap)
	var actual_gap: int = abs(_support.sum_unit_bst(sukuna_unit) - _support.sum_unit_bst(opponent_unit))
	if actual_gap != gap:
		return harness.fail_result("teach love gap fixture mismatch: expected gap=%d actual=%d" % [gap, actual_gap])
	var regen_instance = _find_regen_instance(sukuna_unit)
	if regen_instance == null:
		return harness.fail_result("missing matchup regen rule_mod for gap=%d" % gap)
	if int(regen_instance.value) != expected_bonus:
		return harness.fail_result("teach love bonus mismatch at gap=%d: expected=%d actual=%d" % [gap, expected_bonus, int(regen_instance.value)])
	var expected_turn_regen: int = int(content_index.units["sukuna"].regen_per_turn) + expected_bonus
	var expected_initial_mp: int = mini(int(sukuna_unit.max_mp), int(content_index.units["sukuna"].init_mp) + expected_turn_regen)
	if int(sukuna_unit.current_mp) != expected_initial_mp:
		return harness.fail_result("teach love initial mp mismatch at gap=%d: expected=%d actual=%d" % [gap, expected_initial_mp, int(sukuna_unit.current_mp)])
	var before_turn_mp: int = int(sukuna_unit.current_mp)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 2, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	var expected_next_turn_mp: int = mini(int(sukuna_unit.max_mp), before_turn_mp + expected_turn_regen)
	if int(sukuna_unit.current_mp) != expected_next_turn_mp:
		return harness.fail_result("teach love turn regen mismatch at gap=%d: expected=%d actual=%d" % [gap, expected_next_turn_mp, int(sukuna_unit.current_mp)])
	var resolved_bonus: int = _support.resolve_matchup_gap_value(
		_support.sum_unit_bst(sukuna_unit),
		_support.sum_unit_bst(opponent_unit),
		_band_thresholds(),
		_band_outputs(),
		0
	)
	if resolved_bonus != expected_bonus:
		return harness.fail_result("teach love helper mismatch at gap=%d: expected=%d actual=%d" % [gap, expected_bonus, resolved_bonus])
	return harness.pass_result()

func _override_unit_total_for_gap(unit_definition, gap: int) -> void:
	var target_total: int = SUKUNA_BST_TOTAL - gap
	var fixed_non_hp_mp: int = int(unit_definition.base_attack) \
		+ int(unit_definition.base_defense) \
		+ int(unit_definition.base_sp_attack) \
		+ int(unit_definition.base_sp_defense) \
		+ int(unit_definition.base_speed)
	var remaining_for_hp_mp: int = target_total - fixed_non_hp_mp
	var target_max_mp: int = maxi(1, mini(100, remaining_for_hp_mp - 1))
	var target_hp: int = remaining_for_hp_mp - target_max_mp
	if target_hp < 1:
		target_hp = 1
		target_max_mp = remaining_for_hp_mp - target_hp
	unit_definition.base_hp = target_hp
	unit_definition.max_mp = target_max_mp
	unit_definition.init_mp = mini(int(unit_definition.init_mp), target_max_mp)

func _band_thresholds() -> PackedInt32Array:
	return PackedInt32Array([20, 40, 70, 110, 160])

func _band_outputs() -> PackedInt32Array:
	return PackedInt32Array([9, 8, 7, 6, 5])

func _find_regen_instance(sukuna_unit):
	for instance in sukuna_unit.rule_mod_instances:
		if String(instance.mod_kind) == "mp_regen":
			return instance
	return null
