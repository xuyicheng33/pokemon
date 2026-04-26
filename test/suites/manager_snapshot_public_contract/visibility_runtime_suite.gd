extends "res://test/suites/manager_snapshot_public_contract/base.gd"

func test_visibility_mode_runtime_decoupled_contract() -> void:
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
	var format_config = content_index.battle_formats.get("prototype_full_open", null)
	if format_config == null:
		fail("missing sample battle format")
		return
	format_config.visibility_mode = "test_custom_visibility_mode"
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 406)
	if battle_state.format_id != "prototype_full_open":
		fail("battle_state.format_id should remain battle format id")
		return
	if battle_state.visibility_mode != "test_custom_visibility_mode":
		fail("battle_state.visibility_mode should come from BattleFormatConfig.visibility_mode")
		return
	var stable_state = battle_state.to_stable_dict()
	if str(stable_state.get("visibility_mode", "")) != "test_custom_visibility_mode":
		fail("BattleState.to_stable_dict should serialize visibility_mode from runtime field")
		return
	var public_snapshot = core.service("public_snapshot_builder").build_public_snapshot(battle_state, content_index)
	if str(public_snapshot.get("visibility_mode", "")) != "test_custom_visibility_mode":
		fail("public snapshot should read visibility_mode from battle_state.visibility_mode")
		return
	var header_event = null
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.SYSTEM_BATTLE_HEADER:
			header_event = log_event
			break
	if header_event == null:
		fail("missing system:battle_header log")
		return
	if typeof(header_event.header_snapshot) != TYPE_DICTIONARY:
		fail("header_snapshot should be Dictionary")
		return
	if str(header_event.header_snapshot.get("visibility_mode", "")) != "test_custom_visibility_mode":
		fail("header_snapshot.visibility_mode should read battle_state.visibility_mode")
		return

func test_battle_format_runtime_constants_copy_contract() -> void:
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
	var format_config = content_index.battle_formats.get("prototype_full_open", null)
	if format_config == null:
		fail("missing sample battle format")
		return
	format_config.default_recoil_ratio = 0.5
	format_config.domain_clash_tie_threshold = 0.25
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 4061)
	if not is_equal_approx(float(battle_state.default_recoil_ratio), 0.5):
		fail("battle_state.default_recoil_ratio should come from BattleFormatConfig")
		return
	if not is_equal_approx(float(battle_state.domain_clash_tie_threshold), 0.25):
		fail("battle_state.domain_clash_tie_threshold should come from BattleFormatConfig")
		return
	var stable_state = battle_state.to_stable_dict()
	if not is_equal_approx(float(stable_state.get("default_recoil_ratio", -1.0)), 0.5):
		fail("BattleState.to_stable_dict should serialize default_recoil_ratio")
		return
	if not is_equal_approx(float(stable_state.get("domain_clash_tie_threshold", -1.0)), 0.25):
		fail("BattleState.to_stable_dict should serialize domain_clash_tie_threshold")
		return

