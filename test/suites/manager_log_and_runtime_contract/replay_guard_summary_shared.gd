extends "res://test/suites/manager_log_and_runtime_contract/replay_guard_shared_base.gd"

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
