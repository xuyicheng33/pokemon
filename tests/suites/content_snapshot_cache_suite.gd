extends RefCounted
class_name ContentSnapshotCacheSuite

const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const CommandScript := preload("res://src/battle_core/contracts/command.gd")
const EventLogPublicSnapshotBuilderScript := preload("res://src/battle_core/facades/event_log_public_snapshot_builder.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()
var _event_log_public_snapshot_builder = EventLogPublicSnapshotBuilderScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("content_snapshot_cache_session_and_replay_contract", failures, Callable(self, "_test_content_snapshot_cache_session_and_replay_contract").bind(harness))

func _test_content_snapshot_cache_session_and_replay_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	if manager._container_factory_owner == null or manager._container_factory_owner.composer == null:
		return harness.fail_result("manager should keep composer-backed container factory owner for shared content cache")
	var cache = manager._container_factory_owner.composer.shared_content_snapshot_cache()
	if cache == null:
		return harness.fail_result("shared content snapshot cache should be available")
	cache.clear()

	var content_snapshot_paths = sample_factory.content_snapshot_paths()
	var battle_setup = sample_factory.build_sample_setup()
	var battle_seed := 509
	var baseline_content_index = harness.build_loaded_content_index(sample_factory)
	var baseline_battle_state = harness.build_initialized_battle(core, baseline_content_index, sample_factory, battle_seed, battle_setup)
	var baseline_public_snapshot = _normalize_battle_id(core.service("public_snapshot_builder").build_public_snapshot(baseline_battle_state, baseline_content_index))
	var baseline_event_snapshots = _normalize_public_event_snapshots(
		_build_public_event_snapshots(core.service("battle_logger").snapshot(), baseline_battle_state)
	)

	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": battle_seed,
		"content_snapshot_paths": content_snapshot_paths,
		"battle_setup": sample_factory.build_sample_setup(),
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "manager create_session failed")))
	var init_data: Dictionary = init_unwrap.get("data", {})
	var session_id := String(init_data.get("session_id", ""))
	if session_id.is_empty():
		return harness.fail_result("create_session should return session_id")
	var cached_public_snapshot = _normalize_battle_id(init_data.get("public_snapshot", {}))
	if cached_public_snapshot != baseline_public_snapshot:
		return harness.fail_result("content snapshot cache must preserve create_session public snapshot semantics")
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
	var event_log_snapshot: Dictionary = event_log_unwrap.get("data", {})
	if _normalize_public_event_snapshots(event_log_snapshot.get("events", [])) != baseline_event_snapshots:
		return harness.fail_result("content snapshot cache must preserve initial event log snapshot semantics")
	if int(event_log_snapshot.get("total_size", -1)) != baseline_event_snapshots.size():
		return harness.fail_result("initial event log snapshot total_size must match baseline")
	var session_stats: Dictionary = cache.stats()
	if int(session_stats.get("misses", -1)) != 1 or int(session_stats.get("hits", -1)) != 0 or int(session_stats.get("size", -1)) != 1:
		return harness.fail_result("first create_session should warm exactly one content snapshot cache entry")
	if bool(session_stats.get("last_cache_hit", true)):
		return harness.fail_result("first create_session should be a cache miss")

	var baseline_replay_input = sample_factory.build_demo_replay_input(core.service("command_builder"))
	if baseline_replay_input == null:
		return harness.fail_result("baseline replay input build failed")
	var baseline_replay_copy = _clone_replay_input(baseline_replay_input)
	var cached_replay_copy = _clone_replay_input(baseline_replay_input)
	var baseline_replay_result: Dictionary = core.service("replay_runner").run_replay_with_context(baseline_replay_copy)
	var baseline_replay_output = baseline_replay_result.get("replay_output", null)
	var baseline_replay_content_index = baseline_replay_result.get("content_index", null)
	if baseline_replay_output == null or baseline_replay_content_index == null or not baseline_replay_output.succeeded:
		return harness.fail_result("baseline replay should succeed")
	var baseline_replay_snapshot = core.service("public_snapshot_builder").build_public_snapshot(
		baseline_replay_output.final_battle_state,
		baseline_replay_content_index
	)
	var replay_unwrap = _helper.unwrap_ok(manager.run_replay(cached_replay_copy), "run_replay")
	if not bool(replay_unwrap.get("ok", false)):
		return harness.fail_result(str(replay_unwrap.get("error", "manager run_replay failed")))
	var replay_data: Dictionary = replay_unwrap.get("data", {})
	var cached_replay_output = replay_data.get("replay_output", null)
	if cached_replay_output == null or not cached_replay_output.succeeded:
		return harness.fail_result("cached replay should succeed")
	if replay_data.get("public_snapshot", {}) != baseline_replay_snapshot:
		return harness.fail_result("content snapshot cache must preserve replay public snapshot semantics")
	if cached_replay_output.final_state_hash != baseline_replay_output.final_state_hash:
		return harness.fail_result("content snapshot cache must preserve replay final_state_hash")
	if _stable_log_array(cached_replay_output.event_log) != _stable_log_array(baseline_replay_output.event_log):
		return harness.fail_result("content snapshot cache must preserve replay event log semantics")
	var replay_stats: Dictionary = cache.stats()
	if int(replay_stats.get("misses", -1)) != 1 or int(replay_stats.get("hits", -1)) != 1 or int(replay_stats.get("size", -1)) != 1:
		return harness.fail_result("run_replay should reuse the warmed content snapshot cache entry")
	if not bool(replay_stats.get("last_cache_hit", false)):
		return harness.fail_result("run_replay should report a cache hit after create_session warmed the cache")
	return harness.pass_result()

func _clone_replay_input(replay_input) -> ReplayInputScript:
	var clone = ReplayInputScript.new()
	clone.battle_seed = replay_input.battle_seed
	clone.content_snapshot_paths = replay_input.content_snapshot_paths
	clone.battle_setup = replay_input.battle_setup
	clone.command_stream = []
	for command in replay_input.command_stream:
		clone.command_stream.append(_clone_command(command))
	return clone

func _clone_command(command) -> CommandScript:
	var clone = CommandScript.new()
	if command == null:
		return clone
	clone.command_id = String(command.command_id)
	clone.turn_index = int(command.turn_index)
	clone.command_type = String(command.command_type)
	clone.command_source = String(command.command_source)
	clone.side_id = String(command.side_id)
	clone.actor_id = String(command.actor_id)
	clone.actor_public_id = String(command.actor_public_id)
	clone.skill_id = String(command.skill_id)
	clone.target_unit_id = String(command.target_unit_id)
	clone.target_public_id = String(command.target_public_id)
	clone.target_slot = String(command.target_slot)
	return clone

func _normalize_battle_id(public_snapshot: Dictionary) -> Dictionary:
	var normalized = public_snapshot.duplicate(true)
	if normalized.has("battle_id"):
		normalized["battle_id"] = "__normalized_battle_id__"
	return normalized

func _build_public_event_snapshots(event_log: Array, battle_state) -> Array:
	var public_events: Array = []
	for log_event in event_log:
		public_events.append(_event_log_public_snapshot_builder.build_public_snapshot(log_event, battle_state))
	return public_events

func _normalize_public_event_snapshots(event_snapshots: Array) -> Array:
	var normalized_events: Array = []
	for event_snapshot in event_snapshots:
		var normalized_snapshot: Dictionary = event_snapshot.duplicate(true)
		if normalized_snapshot.has("event_chain_id"):
			normalized_snapshot["event_chain_id"] = "__normalized_event_chain_id__"
		if normalized_snapshot.has("cause_event_id") and normalized_snapshot["cause_event_id"] != null:
			normalized_snapshot["cause_event_id"] = "__normalized_cause_event_id__"
		if normalized_snapshot.has("action_id") and normalized_snapshot["action_id"] != null:
			normalized_snapshot["action_id"] = "__normalized_action_id__"
		normalized_events.append(normalized_snapshot)
	return normalized_events

func _stable_log_array(event_log: Array) -> Array:
	var stable_events: Array = []
	for log_event in event_log:
		stable_events.append(log_event.to_stable_dict())
	return stable_events
