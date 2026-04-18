extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared_base.gd"

func _test_turn_selection_resolver_legal_action_service_failure_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 4112)
	var resolver = core.service("turn_selection_resolver")
	resolver.legal_action_service = NullLegalActionService.new()
	var resolve_result: Dictionary = resolver.resolve_commands_for_turn(battle_state, content_index, [])
	if String(resolve_result.get("invalid_code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("turn selection should surface LegalActionService failure as invalid_state_corruption")
	var locked_commands = resolve_result.get("locked_commands", [])
	if locked_commands is Array and not locked_commands.is_empty():
		return harness.fail_result("turn selection should not lock commands after LegalActionService failure")
	return harness.pass_result()

func _test_turn_selection_resolver_failure_is_atomic_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 4113)
	var resolver = core.service("turn_selection_resolver")
	resolver.legal_action_service = OneSideLegalActionFailureStub.new("P2")
	var resolve_result: Dictionary = resolver.resolve_commands_for_turn(battle_state, content_index, [])
	if String(resolve_result.get("invalid_code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("turn selection atomicity contract should surface legal action failure")
	for side_state in battle_state.sides:
		if side_state.selection_state.selection_locked:
			return harness.fail_result("turn selection failure must not leave selection_locked=true on any side")
		if side_state.selection_state.selected_command != null:
			return harness.fail_result("turn selection failure must not leave selected_command on any side")
	return harness.pass_result()

func _test_turn_selection_resolver_command_builder_failure_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 4114)
	var resolver = core.service("turn_selection_resolver")
	resolver.legal_action_service = OneSideLegalActionFailureStub.new("__never__")
	resolver.command_builder = NullCommandBuilder.new()
	var resolve_result: Dictionary = resolver.resolve_commands_for_turn(battle_state, content_index, [])
	if String(resolve_result.get("invalid_code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("turn selection should surface command_builder failure as invalid_state_corruption")
	if String(resolve_result.get("invalid_message", "")).find("forced command build failure") == -1:
		return harness.fail_result("turn selection should project command_builder error message")
	for side_state in battle_state.sides:
		if side_state.selection_state.selection_locked or side_state.selection_state.selected_command != null:
			return harness.fail_result("command_builder failure must leave every side unlocked")
	return harness.pass_result()

func _test_legal_action_service_rule_mod_failure_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 4115)
	var legal_action_service = core.service("legal_action_service")
	legal_action_service.rule_mod_service = RuleModServiceFailureStub.new()
	legal_action_service.domain_legality_service = DomainLegalityServiceClearStub.new()
	var legal_action_set = legal_action_service.get_legal_actions(battle_state, "P1", content_index)
	if legal_action_set != null:
		return harness.fail_result("LegalActionService should return null when rule_mod_service reports structured failure")
	var error_state: Dictionary = legal_action_service.error_state()
	if String(error_state.get("code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("LegalActionService should project rule_mod_service failure as invalid_state_corruption")
	if String(error_state.get("message", "")).find("rule mod read failed") == -1:
		return harness.fail_result("LegalActionService should preserve rule_mod_service error message")
	return harness.pass_result()
