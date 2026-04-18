extends RefCounted
class_name FormalCharacterManagerSmokeHelper

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func contracts() -> Variant:
	return _helper

func find_case_by_test_name(cases: Array, test_name: String) -> Dictionary:
	for raw_case_spec in cases:
		if not (raw_case_spec is Dictionary):
			continue
		var case_spec: Dictionary = raw_case_spec
		if String(case_spec.get("test_name", "")) == test_name:
			return case_spec
	return {}

func run_named_case(harness, cases: Array, test_name: String, sample_factory = null) -> Dictionary:
	var case_spec := find_case_by_test_name(cases, test_name)
	if case_spec.is_empty():
		return harness.fail_result("formal character manager smoke missing case_spec for %s" % test_name)
	return run_case(harness, case_spec, sample_factory)

func run_case(harness, case_spec: Dictionary, sample_factory = null) -> Dictionary:
	var context: Dictionary = build_context(harness, sample_factory)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var resolved_sample_factory = context["sample_factory"]
	var run_case_callable: Callable = case_spec.get("run_case", Callable())
	if not run_case_callable.is_valid():
		return harness.fail_result("formal character manager smoke missing run_case callable")
	var session_mode := String(case_spec.get("session_mode", "managed")).strip_edges()
	if session_mode == "manual":
		return _run_case_callable(
			harness,
			run_case_callable,
			build_case_state(harness, manager, resolved_sample_factory, "", case_spec)
		)
	if session_mode != "managed":
		return harness.fail_result("formal character manager smoke unsupported session_mode: %s" % session_mode)
	var build_battle_setup: Callable = case_spec.get("build_battle_setup", Callable())
	if not build_battle_setup.is_valid():
		return harness.fail_result("formal character manager smoke missing build_battle_setup callable")
	var battle_seed = case_spec.get("battle_seed", null)
	if not _is_positive_whole_number(battle_seed):
		return harness.fail_result("formal character manager smoke missing positive integer battle_seed")
	var battle_setup = build_battle_setup.call(harness, resolved_sample_factory, case_spec)
	if battle_setup == null:
		return harness.fail_result("formal character manager smoke build_battle_setup returned null")
	if battle_setup is Dictionary and bool(battle_setup.get("ok", true)) == false and battle_setup.has("error"):
		return harness.fail_result(str(battle_setup["error"]))
	var init_unwrap = create_session(
		manager,
		resolved_sample_factory,
		int(battle_seed),
		battle_setup,
		String(case_spec.get("create_label", "create_session"))
	)
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var run_result = _run_case_callable(
		harness,
		run_case_callable,
		build_case_state(harness, manager, resolved_sample_factory, session_id, case_spec)
	)
	if not bool(run_result.get("ok", false)):
		return run_result
	var close_unwrap = close_session(manager, session_id, String(case_spec.get("close_label", "close_session")))
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return run_result

func build_context(harness, sample_factory = null) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return {"error": str(manager_payload["error"])}
	var resolved_sample_factory = sample_factory if sample_factory != null else harness.build_sample_factory()
	if resolved_sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	return {
		"manager": manager_payload["manager"],
		"sample_factory": resolved_sample_factory,
	}

func build_case_state(harness, manager, sample_factory, session_id: String, case_spec: Dictionary) -> Dictionary:
	return {
		"harness": harness,
		"manager": manager,
		"sample_factory": sample_factory,
		"session_id": session_id,
		"case_spec": case_spec,
		"helper": _helper,
		"smoke_helper": self,
	}

func create_session(manager, sample_factory, battle_seed: int, battle_setup, label: String = "create_session") -> Dictionary:
	var snapshot_paths_result: Dictionary = sample_factory.content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return {"ok": false, "error": str(snapshot_paths_result.get("error_message", "content snapshot path build failed"))}
	return _helper.unwrap_ok(manager.create_session({
		"battle_seed": battle_seed,
		"content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
		"battle_setup": battle_setup,
	}), label)

func close_session(manager, session_id: String, label: String = "close_session") -> Dictionary:
	return _helper.unwrap_ok(manager.close_session(session_id), label)

func get_legal_actions_result(manager, session_id: String, side_id: String, label: String = "get_legal_actions") -> Dictionary:
	return _helper.unwrap_ok(manager.get_legal_actions(session_id, side_id), label)

func get_public_snapshot_result(manager, session_id: String, label: String = "get_public_snapshot") -> Dictionary:
	return _helper.unwrap_ok(manager.get_public_snapshot(session_id), label)

func get_event_log_result(manager, session_id: String, label: String = "get_event_log_snapshot", start_index = null) -> Dictionary:
	if start_index == null:
		return _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), label)
	return _helper.unwrap_ok(manager.get_event_log_snapshot(session_id, int(start_index)), label)

func build_command_result(
	manager,
	turn_index: int,
	side_id: String,
	actor_public_id: String,
	action_spec,
	label: String = "build_command"
) -> Dictionary:
	var command_payload := {
		"turn_index": turn_index,
		"command_source": "manual",
		"side_id": side_id,
		"actor_public_id": actor_public_id,
	}
	var resolved_action = _resolve_action_payload(action_spec)
	if not bool(resolved_action.get("ok", false)):
		return resolved_action
	for key in resolved_action.get("data", {}).keys():
		command_payload[key] = resolved_action["data"][key]
	return _helper.unwrap_ok(manager.build_command(command_payload), label)

func run_turn_result(manager, session_id: String, turn_spec: Dictionary) -> Dictionary:
	var turn_index := int(turn_spec.get("turn_index", 0))
	if turn_index <= 0:
		return {"ok": false, "error": "run_turn turn_spec missing positive turn_index"}
	var p1_command = build_command_result(
		manager,
		turn_index,
		"P1",
		String(turn_spec.get("p1_actor_public_id", "P1-A")),
		turn_spec.get("p1_action", "wait"),
		String(turn_spec.get("p1_label", "build_command(P1)"))
	)
	if not bool(p1_command.get("ok", false)):
		return p1_command
	var p2_command = build_command_result(
		manager,
		turn_index,
		"P2",
		String(turn_spec.get("p2_actor_public_id", "P2-A")),
		turn_spec.get("p2_action", "wait"),
		String(turn_spec.get("p2_label", "build_command(P2)"))
	)
	if not bool(p2_command.get("ok", false)):
		return p2_command
	return _helper.unwrap_ok(manager.run_turn(session_id, [
		p1_command.get("data", null),
		p2_command.get("data", null),
	]), String(turn_spec.get("label", "run_turn")))

func run_turn_sequence_result(manager, session_id: String, turn_specs: Array) -> Dictionary:
	for raw_turn_spec in turn_specs:
		if not (raw_turn_spec is Dictionary):
			return {"ok": false, "error": "run_turn sequence item must be Dictionary"}
		var turn_result = run_turn_result(manager, session_id, raw_turn_spec)
		if not bool(turn_result.get("ok", false)):
			return turn_result
	return {"ok": true}

func _run_case_callable(harness, run_case_callable: Callable, case_state: Dictionary) -> Dictionary:
	var run_result = run_case_callable.call(case_state)
	if not (run_result is Dictionary):
		return harness.fail_result("formal character manager smoke run_case must return Dictionary")
	return run_result

func _resolve_action_payload(action_spec) -> Dictionary:
	if typeof(action_spec) == TYPE_STRING:
		var action_text := String(action_spec).strip_edges()
		if action_text.is_empty():
			return {"ok": false, "error": "build_command action_spec cannot be empty"}
		if action_text == "wait":
			return {"ok": true, "data": {"command_type": CommandTypesScript.WAIT}}
		if action_text.begins_with("switch:"):
			return {
				"ok": true,
				"data": {
					"command_type": CommandTypesScript.SWITCH,
					"target_public_id": String(action_text.split(":", false, 1)[1]).strip_edges(),
				},
			}
		return {
			"ok": true,
			"data": {
				"command_type": CommandTypesScript.SKILL,
				"skill_id": action_text,
			},
		}
	if not (action_spec is Dictionary):
		return {"ok": false, "error": "build_command action_spec must be String or Dictionary"}
	var payload: Dictionary = action_spec.duplicate(true)
	if payload.has("command_type"):
		return {"ok": true, "data": payload}
	match String(payload.get("action_kind", "skill")).strip_edges():
		"wait":
			payload["command_type"] = CommandTypesScript.WAIT
		"switch":
			payload["command_type"] = CommandTypesScript.SWITCH
		"ultimate":
			payload["command_type"] = CommandTypesScript.ULTIMATE
		_:
			payload["command_type"] = CommandTypesScript.SKILL
	return {"ok": true, "data": payload}

func _is_positive_whole_number(value) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return numeric_value > 0.0 and is_equal_approx(numeric_value, floor(numeric_value))
