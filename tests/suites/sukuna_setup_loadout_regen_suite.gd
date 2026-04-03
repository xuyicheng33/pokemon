extends RefCounted
class_name SukunaSetupLoadoutRegenSuite

const SukunaSetupRegenTestSupportScript := preload("res://tests/support/sukuna_setup_regen_test_support.gd")

var _support = SukunaSetupRegenTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("sukuna_default_loadout_contract", failures, Callable(self, "_test_sukuna_default_loadout_contract").bind(harness))
	runner.run_test("sukuna_matchup_regen_runtime_path", failures, Callable(self, "_test_sukuna_matchup_regen_runtime_path").bind(harness))
	runner.run_test("sukuna_matchup_bst_includes_max_mp_contract", failures, Callable(self, "_test_sukuna_matchup_bst_includes_max_mp_contract").bind(harness))

func _test_sukuna_default_loadout_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var sukuna = content_index.units.get("sukuna", null)
	if sukuna == null:
		return harness.fail_result("missing sukuna unit definition")
	if sukuna.skill_ids != PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"]):
		return harness.fail_result("sukuna default loadout must stay fixed as 解/捌/开")
	if sukuna.skill_ids.has("sukuna_reverse_ritual"):
		return harness.fail_result("sukuna_reverse_ritual should stay in candidate pool, not default loadout")
	if sukuna.candidate_skill_ids != PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku", "sukuna_reverse_ritual"]):
		return harness.fail_result("sukuna candidate skill pool should be structured as 解/捌/开/反转术式")
	if sukuna.ultimate_skill_id != "sukuna_fukuma_mizushi":
		return harness.fail_result("sukuna ultimate should stay fixed as 伏魔御厨子")
	if int(sukuna.ultimate_points_required) != 3 or int(sukuna.ultimate_points_cap) != 3:
		return harness.fail_result("sukuna ultimate point config should stay fixed as required=3 / cap=3")
	if sukuna.passive_skill_id != "sukuna_teach_love":
		return harness.fail_result("sukuna passive should stay fixed as 教会你爱的是...")
	if not content_index.skills.has("sukuna_reverse_ritual"):
		return harness.fail_result("sukuna candidate skill pool should retain 反转术式 for replacement tests")
	return harness.pass_result()

func _test_sukuna_matchup_regen_runtime_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory), 701)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	if sukuna_unit == null:
		return harness.fail_result("missing sukuna active unit")
	var regen_instances: Array = []
	for instance in sukuna_unit.rule_mod_instances:
		if instance.mod_kind == "mp_regen":
			regen_instances.append(instance)
	if regen_instances.size() != 1:
		return harness.fail_result("sukuna should receive exactly one matchup regen rule_mod on init")
	var expected_value := _support.resolve_matchup_gap_value(
		_support.sum_unit_bst(sukuna_unit),
		_support.sum_unit_bst(battle_state.get_side("P2").get_active_unit()),
		PackedInt32Array([20, 40, 70, 110, 160]),
		PackedInt32Array([9, 8, 7, 6, 5]),
		0
	)
	if int(regen_instances[0].value) != expected_value:
		return harness.fail_result("sukuna matchup regen rule_mod value mismatch: expected=%d actual=%d" % [expected_value, int(regen_instances[0].value)])
	var expected_turn_regen: int = int(content_index.units["sukuna"].regen_per_turn) + expected_value
	var expected_current_mp: int = min(int(sukuna_unit.max_mp), int(content_index.units["sukuna"].init_mp) + expected_turn_regen)
	if int(sukuna_unit.current_mp) != expected_current_mp:
		return harness.fail_result("sukuna initial current_mp should reflect base regen plus matchup bonus: expected=%d actual=%d" % [expected_current_mp, int(sukuna_unit.current_mp)])
	var before_turn_mp: int = sukuna_unit.current_mp
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 2, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	var expected_next_turn_mp: int = min(int(sukuna_unit.max_mp), before_turn_mp + expected_turn_regen)
	if int(sukuna_unit.current_mp) != expected_next_turn_mp:
		return harness.fail_result("sukuna next turn regen should keep base regen plus matchup bonus after the pre-applied first turn: expected=%d actual=%d" % [expected_next_turn_mp, int(sukuna_unit.current_mp)])
	var regen_payload = content_index.effects["sukuna_refresh_love_regen"].payloads[0]
	if String(regen_payload.mod_op) != "add":
		return harness.fail_result("sukuna matchup regen payload should add the matchup table value on top of base regen")
	if int(regen_payload.value) != 0:
		return harness.fail_result("runtime formula must not mutate shared rule_mod payload value")
	return harness.pass_result()

func _test_sukuna_matchup_bst_includes_max_mp_contract(harness) -> Dictionary:
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
		return harness.fail_result("missing sample_tidekit unit definition")
	opponent_definition.max_mp = 250
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory), 712)
	var sukuna_unit = battle_state.get_side("P1").get_active_unit()
	var opponent_unit = battle_state.get_side("P2").get_active_unit()
	if sukuna_unit == null or opponent_unit == null:
		return harness.fail_result("missing active units for matchup bst contract")
	if int(opponent_unit.max_mp) != 250:
		return harness.fail_result("runtime unit max_mp should mirror overridden content definition in this contract test")
	var regen_instance = null
	for instance in sukuna_unit.rule_mod_instances:
		if instance.mod_kind == "mp_regen":
			regen_instance = instance
			break
	if regen_instance == null:
		return harness.fail_result("sukuna matchup regen rule_mod missing")
	var thresholds := PackedInt32Array([20, 40, 70, 110, 160])
	var outputs := PackedInt32Array([9, 8, 7, 6, 5])
	var expected_with_max_mp := _support.resolve_matchup_gap_value(
		_support.sum_unit_bst(sukuna_unit),
		_support.sum_unit_bst(opponent_unit),
		thresholds,
		outputs,
		0
	)
	var expected_without_max_mp := _support.resolve_matchup_gap_value(
		_support.sum_unit_bst(sukuna_unit) - int(sukuna_unit.max_mp),
		_support.sum_unit_bst(opponent_unit) - int(opponent_unit.max_mp),
		thresholds,
		outputs,
		0
	)
	if expected_with_max_mp == expected_without_max_mp:
		return harness.fail_result("max_mp contract test must cross a gap band; current fixture no longer proves the seventh-dimension assumption")
	if int(regen_instance.value) != expected_with_max_mp:
		return harness.fail_result("sukuna matchup regen should use bst gap that includes max_mp: expected=%d actual=%d" % [expected_with_max_mp, int(regen_instance.value)])
	if int(regen_instance.value) == expected_without_max_mp:
		return harness.fail_result("sukuna matchup regen must not fall back to six-stat bst without max_mp")
	return harness.pass_result()
