extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const SukunaSetupRegenTestSupportScript := preload("res://tests/support/sukuna_setup_regen_test_support.gd")

var _support = SukunaSetupRegenTestSupportScript.new()



func test_sukuna_default_loadout_first_ultimate_window_contract() -> void:
	_assert_legacy_result(_test_sukuna_default_loadout_first_ultimate_window_contract(_harness))

func test_sukuna_ritual_loadout_first_ultimate_window_contract() -> void:
	_assert_legacy_result(_test_sukuna_ritual_loadout_first_ultimate_window_contract(_harness))
func _test_sukuna_default_loadout_first_ultimate_window_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory), 710)
	var window_turn = _support.simulate_until_ultimate_window(
		core,
		content_index,
		battle_state,
		func(turn_index: int):
			if turn_index <= 3:
				return _support.build_manual_skill_command(core, turn_index, "P1", "P1-A", "sukuna_kai")
			return _support.build_manual_wait_command(core, turn_index, "P1", "P1-A")
	)
	if window_turn != 4:
		return harness.fail_result("默认装配当前基准线的首次奥义窗口应固定在 turn 4，actual=%d" % window_turn)
	return harness.pass_result()

func _test_sukuna_ritual_loadout_first_ultimate_window_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var ritual_loadout := {0: PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])}
	var battle_state = _support.build_battle_state(core, content_index, _support.build_sukuna_setup(sample_factory, ritual_loadout), 711)
	var window_turn = _support.simulate_until_ultimate_window(
		core,
		content_index,
		battle_state,
		func(turn_index: int):
			if turn_index <= 3:
				return core.service("command_builder").build_command({
					"turn_index": turn_index,
					"command_type": CommandTypesScript.SKILL,
					"command_source": "manual",
					"side_id": "P1",
					"actor_public_id": "P1-A",
					"skill_id": "sukuna_reverse_ritual",
				})
			return _support.build_manual_wait_command(core, turn_index, "P1", "P1-A")
	)
	if window_turn != 4:
		return harness.fail_result("反转术式装配当前基准线的首次奥义窗口应固定在 turn 4，actual=%d" % window_turn)
	return harness.pass_result()
