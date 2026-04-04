extends RefCounted
class_name ContentSnapshotCacheComposerSuite

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("content_snapshot_cache_composer_stats_contract", failures, Callable(self, "_test_content_snapshot_cache_composer_stats_contract").bind(harness))

func _test_content_snapshot_cache_composer_stats_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var composer = manager_payload.get("composer", null)
	if composer == null:
		return harness.fail_result("content snapshot cache composer suite requires composer handle")
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		return harness.fail_result("shared content snapshot cache should be available")
	cache.clear()

	var create_result = manager.create_session({
		"battle_seed": 509,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": sample_factory.build_sample_setup(),
	})
	if not bool(create_result.get("ok", false)):
		return harness.fail_result("create_session should succeed while warming content snapshot cache")
	var session_stats: Dictionary = cache.stats()
	if int(session_stats.get("misses", -1)) != 1 or int(session_stats.get("hits", -1)) != 0 or int(session_stats.get("size", -1)) != 1:
		return harness.fail_result("first create_session should warm exactly one content snapshot cache entry")
	if bool(session_stats.get("last_cache_hit", true)):
		return harness.fail_result("first create_session should be a cache miss")

	var replay_input = sample_factory.build_demo_replay_input(core.service("command_builder"))
	if replay_input == null:
		return harness.fail_result("replay input build failed")
	var replay_result = manager.run_replay(replay_input)
	if not bool(replay_result.get("ok", false)):
		return harness.fail_result("run_replay should succeed while reusing content snapshot cache")
	var replay_stats: Dictionary = cache.stats()
	if int(replay_stats.get("misses", -1)) != 1 or int(replay_stats.get("hits", -1)) != 1 or int(replay_stats.get("size", -1)) != 1:
		return harness.fail_result("run_replay should reuse the warmed content snapshot cache entry")
	if not bool(replay_stats.get("last_cache_hit", false)):
		return harness.fail_result("run_replay should report a cache hit after create_session warmed the cache")
	return harness.pass_result()
