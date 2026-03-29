extends RefCounted
class_name ManagerReplayHeaderContractSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("replay_snapshot_contract", failures, Callable(self, "_test_replay_snapshot_contract").bind(harness))
	runner.run_test("log_v3_header_contract", failures, Callable(self, "_test_log_v3_header_contract").bind(harness))
	runner.run_test("header_snapshot_private_id_guard", failures, Callable(self, "_test_header_snapshot_private_id_guard").bind(harness))

func _test_replay_snapshot_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var live_result = manager.create_session({"battle_seed": 405, "content_snapshot_paths": sample_factory.content_snapshot_paths(), "battle_setup": sample_factory.build_sample_setup()})
	var live_snapshot = live_result.get("public_snapshot", {})
	var replay_result: Dictionary = manager.run_replay(sample_factory.build_demo_replay_input(manager))
	var replay_snapshot = replay_result.get("public_snapshot", {})
	if typeof(replay_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("run_replay should expose public_snapshot")
	if not replay_snapshot.has("prebattle_public_teams"):
		return harness.fail_result("replay public_snapshot missing prebattle_public_teams")
	var shape_error = _helper.validate_snapshot_shape(replay_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("replay snapshot shape invalid: %s" % shape_error)
	var live_shape_error = _helper.validate_snapshot_shape(live_snapshot)
	if not live_shape_error.is_empty():
		return harness.fail_result("live snapshot shape invalid: %s" % live_shape_error)
	if replay_snapshot.get("visibility_mode", "") != live_snapshot.get("visibility_mode", ""):
		return harness.fail_result("replay snapshot visibility_mode should match live contract")
	return harness.pass_result()

func _test_log_v3_header_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_result: Dictionary = manager.run_replay(sample_factory.build_demo_replay_input(manager))
	var replay_output = replay_result.get("replay_output", null)
	if replay_output == null:
		return harness.fail_result("run_replay should return replay_output")
	var header_count: int = 0
	var header_index: int = -1
	var first_enter_index: int = -1
	for i in range(replay_output.event_log.size()):
		var ev = replay_output.event_log[i]
		if int(ev.log_schema_version) != 3:
			return harness.fail_result("log_schema_version should be 3 for all events")
		if ev.event_type == EventTypesScript.SYSTEM_BATTLE_HEADER:
			header_count += 1
			header_index = i
		if first_enter_index == -1 and ev.event_type == EventTypesScript.STATE_ENTER:
			first_enter_index = i
	if header_count != 1:
		return harness.fail_result("system:battle_header should appear exactly once")
	if first_enter_index == -1:
		return harness.fail_result("state:enter should exist")
	if not (header_index < first_enter_index):
		return harness.fail_result("system:battle_header must be earlier than first state:enter")
	return harness.pass_result()

func _test_header_snapshot_private_id_guard(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_result: Dictionary = manager.run_replay(sample_factory.build_demo_replay_input(manager))
	var replay_output = replay_result.get("replay_output", null)
	if replay_output == null:
		return harness.fail_result("run_replay should return replay_output")
	var header_event = null
	for ev in replay_output.event_log:
		if ev.event_type == EventTypesScript.SYSTEM_BATTLE_HEADER:
			header_event = ev
			break
	if header_event == null:
		return harness.fail_result("missing system:battle_header event")
	var header_snapshot = header_event.header_snapshot
	if typeof(header_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("header_snapshot should be Dictionary")
	var required_fields: Array[String] = ["visibility_mode", "prebattle_public_teams", "initial_active_public_ids_by_side", "initial_field"]
	for field_name in required_fields:
		if not header_snapshot.has(field_name):
			return harness.fail_result("header_snapshot missing required field: %s" % field_name)
	if _helper.contains_private_instance_id_key(header_snapshot):
		return harness.fail_result("header_snapshot should not contain private instance IDs")
	return harness.pass_result()
