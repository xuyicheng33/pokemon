extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")
const ObitoRuntimeContractSupportScript := preload("res://tests/support/obito_runtime_contract_support.gd")

var _support = ObitoTestSupportScript.new()
var _contract_support = ObitoRuntimeContractSupportScript.new()


func test_obito_passive_missing_hp_heal_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), 1510)
	var obito = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if obito == null or target == null:
		fail("missing active units for obito passive contract")
		return
	obito.current_hp = obito.max_hp - 1

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	if int(obito.current_hp) != int(obito.max_hp):
		fail("obito passive should heal 1 when missing_hp is 1 under current shared contract")
		return

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 2, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	if _support.collect_target_heal_events(core.service("battle_logger").event_log, obito.unit_instance_id).size() != 0:
		fail("obito passive should not write heal event while already at full hp")
		return

func test_obito_qiudao_jiaotu_heal_block_contract() -> void:
	var __legacy_result = _contract_support.run_qiudao_jiaotu_heal_block_contract(_harness)
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

func test_obito_qiudao_jiaotu_expire_sync_contract() -> void:
	var __legacy_result = _contract_support.run_qiudao_jiaotu_expire_sync_contract(_harness)
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

func test_obito_qiudao_jiaotu_switch_persist_contract() -> void:
	var __legacy_result = _contract_support.run_qiudao_jiaotu_switch_persist_contract(_harness)
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

