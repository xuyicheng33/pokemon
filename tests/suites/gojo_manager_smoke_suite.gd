extends RefCounted
class_name GojoManagerSmokeSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("gojo_manager_smoke_contract", failures, Callable(self, "_test_gojo_manager_smoke_contract").bind(harness))

func _test_gojo_manager_smoke_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": 1301,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": sample_factory.build_gojo_vs_sample_setup(),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var session = manager._debug_session(session_id)
	if session == null:
		return harness.fail_result("gojo manager smoke missing internal session")
	var gojo_ao = session.content_index.skills.get("gojo_ao", null)
	if gojo_ao == null:
		return harness.fail_result("gojo manager smoke missing gojo_ao skill")
	gojo_ao.accuracy = 100
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
	var legal_actions = legal_actions_unwrap.get("data", null)
	if String(legal_actions.actor_public_id) != "P1-A":
		return harness.fail_result("gojo manager smoke should expose actor_public_id=P1-A")
	if not legal_actions.legal_skill_ids.has("gojo_ao"):
		return harness.fail_result("gojo manager smoke legal actions should include gojo_ao")
	var gojo_command_unwrap = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "gojo_ao",
	}), "build_command(gojo_ao)")
	if not bool(gojo_command_unwrap.get("ok", false)):
		return harness.fail_result(str(gojo_command_unwrap.get("error", "manager build_command failed")))
	var wait_command_unwrap = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command(wait)")
	if not bool(wait_command_unwrap.get("ok", false)):
		return harness.fail_result(str(wait_command_unwrap.get("error", "manager build_command failed")))
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		gojo_command_unwrap.get("data", null),
		wait_command_unwrap.get("data", null),
	]), "run_turn")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "manager run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "manager get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error := _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("gojo manager smoke public snapshot malformed: %s" % shape_error)
	var target_snapshot := _find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if target_snapshot.is_empty():
		return harness.fail_result("gojo manager smoke missing target public snapshot")
	if not _unit_has_effect(target_snapshot, "gojo_ao_mark"):
		return harness.fail_result("gojo manager smoke should expose gojo_ao_mark on P2-A")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var event_log_snapshot: Dictionary = event_log_unwrap.get("data", {})
	var events: Array = event_log_snapshot.get("events", [])
	if events.is_empty():
		return harness.fail_result("gojo manager smoke event log should not be empty after run_turn")
	if _contains_runtime_id_leak(events):
		return harness.fail_result("gojo manager smoke event log must stay public-safe")
	if not _has_public_action_cast(events, "P1-A", "gojo_satoru"):
		return harness.fail_result("gojo manager smoke event log should expose gojo public action cast")
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "manager close_session failed")))
	return harness.pass_result()

func _find_unit_snapshot(public_snapshot: Dictionary, side_id: String, public_id: String) -> Dictionary:
	for side_snapshot in public_snapshot.get("sides", []):
		if String(side_snapshot.get("side_id", "")) != side_id:
			continue
		for unit_snapshot in side_snapshot.get("team_units", []):
			if String(unit_snapshot.get("public_id", "")) == public_id:
				return unit_snapshot
	return {}

func _unit_has_effect(unit_snapshot: Dictionary, effect_id: String) -> bool:
	for effect_snapshot in unit_snapshot.get("effect_instances", []):
		if String(effect_snapshot.get("effect_definition_id", "")) == effect_id:
			return true
	return false

func _contains_runtime_id_leak(value) -> bool:
	return _helper.contains_any_key_recursive(value, PackedStringArray([
		"actor_id",
		"source_instance_id",
		"target_instance_id",
		"killer_id",
		"entity_id",
	])) or _helper.contains_private_instance_id_key(value)

func _has_public_action_cast(events: Array, actor_public_id: String, actor_definition_id: String) -> bool:
	for event_snapshot in events:
		if String(event_snapshot.get("event_type", "")) != EventTypesScript.ACTION_CAST:
			continue
		if String(event_snapshot.get("actor_public_id", "")) == actor_public_id \
		and String(event_snapshot.get("actor_definition_id", "")) == actor_definition_id:
			return true
	return false
