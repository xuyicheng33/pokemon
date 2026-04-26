extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared_base.gd"

func test_turn_selection_resolver_legal_action_service_failure_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 4112)
	var resolver = core.service("turn_selection_resolver")
	resolver.legal_action_service = NullLegalActionService.new()
	var resolve_result: Dictionary = resolver.resolve_commands_for_turn(battle_state, content_index, [])
	if String(resolve_result.get("invalid_code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("turn selection should surface LegalActionService failure as invalid_state_corruption")
		return
	var locked_commands = resolve_result.get("locked_commands", [])
	if locked_commands is Array and not locked_commands.is_empty():
		fail("turn selection should not lock commands after LegalActionService failure")
		return

func test_turn_selection_resolver_failure_is_atomic_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 4113)
	var resolver = core.service("turn_selection_resolver")
	resolver.legal_action_service = OneSideLegalActionFailureStub.new("P2")
	var resolve_result: Dictionary = resolver.resolve_commands_for_turn(battle_state, content_index, [])
	if String(resolve_result.get("invalid_code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("turn selection atomicity contract should surface legal action failure")
		return
	for side_state in battle_state.sides:
		if side_state.selection_state.selection_locked:
			fail("turn selection failure must not leave selection_locked=true on any side")
			return
		if side_state.selection_state.selected_command != null:
			fail("turn selection failure must not leave selected_command on any side")
			return

func test_turn_selection_resolver_command_builder_failure_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 4114)
	var resolver = core.service("turn_selection_resolver")
	resolver.legal_action_service = OneSideLegalActionFailureStub.new("__never__")
	resolver.command_builder = NullCommandBuilder.new()
	var resolve_result: Dictionary = resolver.resolve_commands_for_turn(battle_state, content_index, [])
	if String(resolve_result.get("invalid_code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("turn selection should surface command_builder failure as invalid_state_corruption")
		return
	if String(resolve_result.get("invalid_message", "")).find("forced command build failure") == -1:
		fail("turn selection should project command_builder error message")
		return
	for side_state in battle_state.sides:
		if side_state.selection_state.selection_locked or side_state.selection_state.selected_command != null:
			fail("command_builder failure must leave every side unlocked")
			return

func test_legal_action_service_rule_mod_failure_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 4115)
	var legal_action_service = core.service("legal_action_service")
	legal_action_service.rule_mod_service = RuleModServiceFailureStub.new()
	legal_action_service.domain_legality_service = DomainLegalityServiceClearStub.new()
	var legal_action_set = legal_action_service.get_legal_actions(battle_state, "P1", content_index)
	if legal_action_set != null:
		fail("LegalActionService should return null when rule_mod_service reports structured failure")
		return
	var error_state: Dictionary = legal_action_service.error_state()
	if String(error_state.get("code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("LegalActionService should project rule_mod_service failure as invalid_state_corruption")
		return
	if String(error_state.get("message", "")).find("rule mod read failed") == -1:
		fail("LegalActionService should preserve rule_mod_service error message")
		return
