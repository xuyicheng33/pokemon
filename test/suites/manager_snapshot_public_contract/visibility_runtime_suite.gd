extends "res://test/suites/manager_snapshot_public_contract/base.gd"
const BaseSuiteScript := preload("res://test/suites/manager_snapshot_public_contract/base.gd")



func test_visibility_mode_runtime_decoupled_contract() -> void:
	_assert_legacy_result(_test_visibility_mode_runtime_decoupled_contract(_harness))

func test_battle_format_runtime_constants_copy_contract() -> void:
	_assert_legacy_result(_test_battle_format_runtime_constants_copy_contract(_harness))
func _test_visibility_mode_runtime_decoupled_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var format_config = content_index.battle_formats.get("prototype_full_open", null)
	if format_config == null:
		return harness.fail_result("missing sample battle format")
	format_config.visibility_mode = "test_custom_visibility_mode"
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 406)
	if battle_state.format_id != "prototype_full_open":
		return harness.fail_result("battle_state.format_id should remain battle format id")
	if battle_state.visibility_mode != "test_custom_visibility_mode":
		return harness.fail_result("battle_state.visibility_mode should come from BattleFormatConfig.visibility_mode")
	var stable_state = battle_state.to_stable_dict()
	if str(stable_state.get("visibility_mode", "")) != "test_custom_visibility_mode":
		return harness.fail_result("BattleState.to_stable_dict should serialize visibility_mode from runtime field")
	var public_snapshot = core.service("public_snapshot_builder").build_public_snapshot(battle_state, content_index)
	if str(public_snapshot.get("visibility_mode", "")) != "test_custom_visibility_mode":
		return harness.fail_result("public snapshot should read visibility_mode from battle_state.visibility_mode")
	var header_event = null
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.SYSTEM_BATTLE_HEADER:
			header_event = log_event
			break
	if header_event == null:
		return harness.fail_result("missing system:battle_header log")
	if typeof(header_event.header_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("header_snapshot should be Dictionary")
	if str(header_event.header_snapshot.get("visibility_mode", "")) != "test_custom_visibility_mode":
		return harness.fail_result("header_snapshot.visibility_mode should read battle_state.visibility_mode")
	return harness.pass_result()

func _test_battle_format_runtime_constants_copy_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var format_config = content_index.battle_formats.get("prototype_full_open", null)
	if format_config == null:
		return harness.fail_result("missing sample battle format")
	format_config.default_recoil_ratio = 0.5
	format_config.domain_clash_tie_threshold = 0.25
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 4061)
	if not is_equal_approx(float(battle_state.default_recoil_ratio), 0.5):
		return harness.fail_result("battle_state.default_recoil_ratio should come from BattleFormatConfig")
	if not is_equal_approx(float(battle_state.domain_clash_tie_threshold), 0.25):
		return harness.fail_result("battle_state.domain_clash_tie_threshold should come from BattleFormatConfig")
	var stable_state = battle_state.to_stable_dict()
	if not is_equal_approx(float(stable_state.get("default_recoil_ratio", -1.0)), 0.5):
		return harness.fail_result("BattleState.to_stable_dict should serialize default_recoil_ratio")
	if not is_equal_approx(float(stable_state.get("domain_clash_tie_threshold", -1.0)), 0.25):
		return harness.fail_result("BattleState.to_stable_dict should serialize domain_clash_tie_threshold")
	return harness.pass_result()
