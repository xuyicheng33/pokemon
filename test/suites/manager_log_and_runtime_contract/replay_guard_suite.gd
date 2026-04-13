extends "res://test/support/gdunit_suite_bridge.gd"

const BattleCoreManagerContainerServiceScript := preload("res://src/battle_core/facades/battle_core_manager_container_service.gd")
const BattleResultScript := preload("res://src/battle_core/contracts/battle_result.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const LogEventBuilderScript := preload("res://src/battle_core/logging/log_event_builder.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const ReplayOutputScript := preload("res://src/battle_core/contracts/replay_output.gd")
const ReplayRunnerOutputHelperScript := preload("res://src/battle_core/logging/replay_runner_output_helper.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

class ReplayRunnerStub:
	var replay_result: Dictionary = {}

	func _init(next_replay_result: Dictionary) -> void:
		replay_result = next_replay_result

	func run_replay_with_context(_replay_input) -> Dictionary:
		return replay_result

class ContainerStub:
	var services: Dictionary = {}
	var disposed: bool = false

	func _init(next_services: Dictionary) -> void:
		services = next_services

	func service(slot: String):
		return services.get(slot, null)

	func dispose() -> void:
		disposed = true

class PublicSnapshotBuilderStub:
	var build_calls: int = 0

	func build_public_snapshot(_battle_state, _content_index):
		build_calls += 1
		return {"public_snapshot": true}

class NullLegalActionService:
	func get_legal_actions(_battle_state, _side_id: String, _content_index):
		return null

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "forced legal action failure",
		}

class OneSideLegalActionFailureStub:
	var _failed_side_id: String = ""

	func _init(failed_side_id: String) -> void:
		_failed_side_id = failed_side_id

	func get_legal_actions(_battle_state, side_id: String, _content_index):
		if side_id == _failed_side_id:
			return null
		return LegalActionSetScript.new()

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "partial legal action failure",
		}

class NullCommandBuilder:
	func build_command(_input_payload: Dictionary):
		return null

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "forced command build failure",
		}

class RuleModServiceFailureStub:
	func is_action_allowed(_battle_state, _owner_id: String, _action_type: String, _skill_id: String = "") -> bool:
		return false

	func error_state() -> Dictionary:
		return {
			"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"message": "rule mod read failed",
		}

class DomainLegalityServiceClearStub:
	func is_side_domain_recast_blocked(_battle_state, _side_id: String, _content_index) -> bool:
		return false

	func invalid_battle_code() -> Variant:
		return null



func test_manager_run_replay_empty_snapshot_paths_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_empty_snapshot_paths_contract(_harness))

func test_manager_run_replay_invalid_input_type_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_invalid_input_type_contract(_harness))

func test_manager_run_replay_null_command_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_null_command_contract(_harness))

func test_manager_run_replay_invalid_side_id_contract() -> void:
	_assert_legacy_result(_test_manager_run_replay_invalid_side_id_contract(_harness))

func test_manager_container_run_replay_failed_output_contract() -> void:
	_assert_legacy_result(_test_manager_container_run_replay_failed_output_contract())

func test_replay_output_helper_runtime_fault_contract() -> void:
	_assert_legacy_result(_test_replay_output_helper_runtime_fault_contract())

func test_replay_output_helper_logger_fault_contract() -> void:
	_assert_legacy_result(_test_replay_output_helper_logger_fault_contract())

func test_log_event_builder_missing_chain_context_contract() -> void:
	_assert_legacy_result(_test_log_event_builder_missing_chain_context_contract())

func test_log_event_builder_missing_cause_event_id_contract() -> void:
	_assert_legacy_result(_test_log_event_builder_missing_cause_event_id_contract())

func test_turn_selection_resolver_legal_action_service_failure_contract() -> void:
	_assert_legacy_result(_test_turn_selection_resolver_legal_action_service_failure_contract(_harness))

func test_turn_selection_resolver_failure_is_atomic_contract() -> void:
	_assert_legacy_result(_test_turn_selection_resolver_failure_is_atomic_contract(_harness))

func test_turn_selection_resolver_command_builder_failure_contract() -> void:
	_assert_legacy_result(_test_turn_selection_resolver_command_builder_failure_contract(_harness))

func test_legal_action_service_rule_mod_failure_contract() -> void:
	_assert_legacy_result(_test_legal_action_service_rule_mod_failure_contract(_harness))
func _test_manager_run_replay_empty_snapshot_paths_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = harness.build_demo_replay_input(sample_factory, manager)
	if replay_input == null:
		return harness.fail_result("demo replay input build failed")
	replay_input.content_snapshot_paths = PackedStringArray()
	var failure = _helper.expect_failure_code(
		manager.run_replay(replay_input),
		"run_replay",
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"non-empty content_snapshot_paths"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_replay empty snapshot paths contract failed")))
	return harness.pass_result()

func _test_manager_run_replay_invalid_input_type_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var failure = _helper.expect_failure_code(
		manager.run_replay(123),
		"run_replay",
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"requires battle_setup"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_replay invalid input type contract failed")))
	return harness.pass_result()

func _test_manager_run_replay_null_command_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = 3092
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = harness.build_sample_setup(sample_factory)
	replay_input.command_stream = [null]
	var failure = _helper.expect_failure_code(
		manager.run_replay(replay_input),
		"run_replay",
		ErrorCodesScript.INVALID_REPLAY_INPUT,
		"command_stream[0] must not be null"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "manager run_replay null command contract failed")))
	return harness.pass_result()

func _test_manager_run_replay_invalid_side_id_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var cases: Array = [
		{"p1_side_id": "", "p2_side_id": "P2", "needle": "battle_setup.sides[0].side_id to be non-empty"},
		{"p1_side_id": "P1", "p2_side_id": "P1", "needle": "duplicated battle_setup side_id: P1"},
	]
	for test_case in cases:
		var replay_input = harness.build_demo_replay_input(sample_factory, manager)
		if replay_input == null:
			return harness.fail_result("demo replay input build failed")
		replay_input.battle_setup.sides[0].side_id = String(test_case["p1_side_id"])
		replay_input.battle_setup.sides[1].side_id = String(test_case["p2_side_id"])
		var failure = _helper.expect_failure_code(
			manager.run_replay(replay_input),
			"run_replay",
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			String(test_case["needle"])
		)
		if not bool(failure.get("ok", false)):
			return harness.fail_result(str(failure.get("error", "manager run_replay invalid side_id contract failed")))
	return harness.pass_result()

func _test_manager_container_run_replay_failed_output_contract() -> Dictionary:
	var cases: Array = [
		{
			"name": "unfinished replay",
			"replay_output": _build_failed_replay_output(false, "", "", null),
			"expected_error": "did not complete",
		},
		{
			"name": "invalid battle_result",
			"replay_output": _build_failed_replay_output(true, "win", "turn_limit", null),
			"expected_error": "invalid battle_result",
		},
		{
			"name": "invalid log schema",
			"replay_output": _build_failed_replay_output(true, "no_winner", "invalid_state_corruption", null),
			"expected_error": "log schema validation failed",
		},
	]
	for raw_case in cases:
		var case_spec: Dictionary = raw_case
		var replay_output = case_spec.get("replay_output", null)
		var replay_runner := ReplayRunnerStub.new({
			"replay_output": replay_output,
			"content_index": {"mock": true},
		})
		var container := ContainerStub.new({
			"replay_runner": replay_runner,
		})
		var public_snapshot_builder := PublicSnapshotBuilderStub.new()
		var container_service := BattleCoreManagerContainerServiceScript.new()
		container_service.container_factory = func():
			return container
		container_service.public_snapshot_builder = public_snapshot_builder
		var result: Dictionary = container_service.run_replay_result({})
		if bool(result.get("ok", true)):
			return {
				"ok": false,
				"error": "%s should return failure envelope when replay_output.succeeded=false" % String(case_spec.get("name", "replay case")),
			}
		if result.get("data", "sentinel") != null:
			return {
				"ok": false,
				"error": "%s should return data=null on replay failure" % String(case_spec.get("name", "replay case")),
			}
		if String(result.get("error_code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
			return {
				"ok": false,
				"error": "%s should report invalid_state_corruption when replay_output contract fails: %s" % [
					String(case_spec.get("name", "replay case")),
					var_to_str(result),
				],
			}
		if String(result.get("error_message", "")).find(String(case_spec.get("expected_error", ""))) == -1:
			return {
				"ok": false,
				"error": "%s failure message drifted: %s" % [
					String(case_spec.get("name", "replay case")),
					String(result.get("error_message", "")),
				],
			}
		if public_snapshot_builder.build_calls != 0:
			return {
				"ok": false,
				"error": "%s must not build public_snapshot after replay contract failure" % String(case_spec.get("name", "replay case")),
			}
		if not container.disposed:
			return {
				"ok": false,
				"error": "%s should dispose temporary container before returning" % String(case_spec.get("name", "replay case")),
			}
	return {
		"ok": true,
	}

func _test_replay_output_helper_runtime_fault_contract() -> Dictionary:
	var helper = ReplayRunnerOutputHelperScript.new()
	var battle_state = _build_finished_battle_state()
	battle_state.runtime_fault_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
	battle_state.runtime_fault_message = "runtime fault latched"
	var result = helper.build_replay_output_result([], battle_state)
	if bool(result.get("ok", true)):
		return {
			"ok": false,
			"error": "ReplayRunnerOutputHelper should fail when battle_state.runtime_fault_code is latched",
		}
	var replay_output = result.get("replay_output", null)
	if replay_output == null or bool(replay_output.succeeded):
		return {
			"ok": false,
			"error": "ReplayRunnerOutputHelper should mark replay_output as failed on runtime fault",
		}
	if String(result.get("error_message", "")).find("runtime fault latched") == -1:
		return {
			"ok": false,
			"error": "ReplayRunnerOutputHelper runtime fault message drifted",
		}
	return {"ok": true}

func _test_replay_output_helper_logger_fault_contract() -> Dictionary:
	var helper = ReplayRunnerOutputHelperScript.new()
	var battle_state = _build_finished_battle_state()
	var result = helper.build_replay_output_result([], battle_state, {
		"code": ErrorCodesScript.INVALID_STATE_CORRUPTION,
		"message": "battle logger fault",
	})
	if bool(result.get("ok", true)):
		return {
			"ok": false,
			"error": "ReplayRunnerOutputHelper should fail when battle_logger.error_state is non-empty",
		}
	var replay_output = result.get("replay_output", null)
	if replay_output == null or bool(replay_output.succeeded):
		return {
			"ok": false,
			"error": "ReplayRunnerOutputHelper should mark replay_output as failed on logger fault",
		}
	if String(result.get("error_message", "")).find("battle logger fault") == -1:
		return {
			"ok": false,
			"error": "ReplayRunnerOutputHelper logger fault message drifted",
		}
	return {"ok": true}

func _test_log_event_builder_missing_chain_context_contract() -> Dictionary:
	var builder := LogEventBuilderScript.new()
	var battle_state := BattleStateScript.new()
	var log_event = builder.build_event("system:test", battle_state)
	if log_event != null:
		return {
			"ok": false,
			"error": "LogEventBuilder should return null when chain_context is missing",
		}
	var error_state: Dictionary = builder.error_state()
	if String(error_state.get("code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return {
			"ok": false,
			"error": "LogEventBuilder missing chain_context should report invalid_state_corruption",
		}
	if String(error_state.get("message", "")).find("missing chain_context") == -1:
		return {
			"ok": false,
			"error": "LogEventBuilder missing chain_context error message drifted",
		}
	return {
		"ok": true,
	}

func _test_log_event_builder_missing_cause_event_id_contract() -> Dictionary:
	var builder := LogEventBuilderScript.new()
	var battle_state := BattleStateScript.new()
	var chain_context := ChainContextScript.new()
	chain_context.event_chain_id = "chain_test"
	battle_state.chain_context = chain_context
	var log_event = builder.build_effect_event("effect:damage", battle_state, "")
	if log_event != null:
		return {
			"ok": false,
			"error": "LogEventBuilder should return null when cause_event_id is empty",
		}
	var error_state: Dictionary = builder.error_state()
	if String(error_state.get("code", "")) != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return {
			"ok": false,
			"error": "LogEventBuilder missing cause_event_id should report invalid_state_corruption",
		}
	if String(error_state.get("message", "")).find("requires real cause_event_id") == -1:
		return {
			"ok": false,
			"error": "LogEventBuilder missing cause_event_id error message drifted",
		}
	return {
		"ok": true,
	}

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

func _build_failed_replay_output(finished: bool, result_type: String, reason: String, winner_side_id) -> Variant:
	var replay_output := ReplayOutputScript.new()
	replay_output.succeeded = false
	replay_output.event_log = []
	replay_output.final_state_hash = "failed"
	var battle_result := BattleResultScript.new()
	battle_result.finished = finished
	battle_result.result_type = result_type
	battle_result.reason = reason
	battle_result.winner_side_id = winner_side_id
	replay_output.battle_result = battle_result
	replay_output.final_battle_state = BattleStateScript.new()
	return replay_output

func _build_finished_battle_state() -> BattleStateScript:
	var battle_state := BattleStateScript.new()
	var battle_result := BattleResultScript.new()
	battle_result.finished = true
	battle_result.result_type = "no_winner"
	battle_result.reason = "turn_limit"
	battle_result.winner_side_id = null
	battle_state.battle_result = battle_result
	return battle_state
