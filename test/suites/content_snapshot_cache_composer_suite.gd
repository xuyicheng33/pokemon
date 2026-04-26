extends "res://tests/support/gdunit_suite_bridge.gd"

const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")


func test_content_snapshot_cache_composer_stats_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache composer suite requires composer handle")
		return
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var replay_input = _harness.build_demo_replay_input(sample_factory, core.service("command_builder"))
	if replay_input == null:
		fail("replay input build failed")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	cache.clear()

	var create_result = manager.create_session({
		"battle_seed": 509,
		"content_snapshot_paths": replay_input.content_snapshot_paths,
		"battle_setup": replay_input.battle_setup,
	})
	if not bool(create_result.get("ok", false)):
		fail("create_session should succeed while warming content snapshot cache")
		return
	var session_stats: Dictionary = cache.stats()
	if int(session_stats.get("misses", -1)) != 1 or int(session_stats.get("hits", -1)) != 0 or int(session_stats.get("size", -1)) != 1:
		fail("first create_session should warm exactly one content snapshot cache entry")
		return
	if bool(session_stats.get("last_cache_hit", true)):
		fail("first create_session should be a cache miss")
		return

	var replay_result = manager.run_replay(replay_input)
	if not bool(replay_result.get("ok", false)):
		fail("run_replay should succeed while reusing content snapshot cache")
		return
	var replay_stats: Dictionary = cache.stats()
	if int(replay_stats.get("misses", -1)) != 1 or int(replay_stats.get("hits", -1)) != 1 or int(replay_stats.get("size", -1)) != 1:
		fail("run_replay should reuse the warmed content snapshot cache entry")
		return
	if not bool(replay_stats.get("last_cache_hit", false)):
		fail("run_replay should report a cache hit after create_session warmed the cache")
		return

func test_content_snapshot_cache_signature_tracks_file_content_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache signature contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var probe_path := "user://content_snapshot_cache_signature_probe.txt"
	var first_write = FileAccess.open(probe_path, FileAccess.WRITE)
	if first_write == null:
		fail("failed to create cache signature probe file")
		return
	first_write.store_string("alpha")
	first_write.close()
	var first_signature := String(cache._build_signature(PackedStringArray([probe_path])))
	var second_write = FileAccess.open(probe_path, FileAccess.WRITE)
	if second_write == null:
		fail("failed to rewrite cache signature probe file")
		return
	second_write.store_string("beta")
	second_write.close()
	var second_signature := String(cache._build_signature(PackedStringArray([probe_path])))
	DirAccess.remove_absolute(probe_path)
	if first_signature.is_empty() or second_signature.is_empty():
		fail("cache signature should not be empty for probe file")
		return
	if first_signature == second_signature:
		fail("cache signature should change when file content changes under the same path")
		return

func test_content_snapshot_cache_signature_tracks_external_resource_dependency_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache dependency contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var shared_probe_path := "user://content_snapshot_cache_shared_dependency_probe.tres"
	var effect_probe_path := "user://content_snapshot_cache_effect_dependency_probe.tres"
	var shared_payload = DamagePayloadScript.new()
	shared_payload.payload_type = "damage"
	shared_payload.amount = 7
	shared_payload.use_formula = false
	if ResourceSaver.save(shared_payload, shared_probe_path) != OK:
		fail("failed to create shared dependency probe resource")
		return
	var loaded_shared_payload = ResourceLoader.load(shared_probe_path)
	if loaded_shared_payload == null:
		DirAccess.remove_absolute(shared_probe_path)
		fail("failed to load shared dependency probe resource")
		return
	var effect_definition = EffectDefinitionScript.new()
	effect_definition.id = "content_snapshot_cache_dependency_probe"
	effect_definition.display_name = "content_snapshot_cache_dependency_probe"
	effect_definition.scope = "self"
	effect_definition.trigger_names = PackedStringArray(["on_hit"])
	effect_definition.payloads.append(loaded_shared_payload)
	if ResourceSaver.save(effect_definition, effect_probe_path) != OK:
		DirAccess.remove_absolute(shared_probe_path)
		fail("failed to create effect dependency probe resource")
		return
	var first_signature := String(cache._build_signature(PackedStringArray([effect_probe_path])))
	var updated_shared_payload = DamagePayloadScript.new()
	updated_shared_payload.payload_type = "damage"
	updated_shared_payload.amount = 9
	updated_shared_payload.use_formula = false
	if ResourceSaver.save(updated_shared_payload, shared_probe_path) != OK:
		DirAccess.remove_absolute(effect_probe_path)
		DirAccess.remove_absolute(shared_probe_path)
		fail("failed to rewrite shared dependency probe resource")
		return
	var second_signature := String(cache._build_signature(PackedStringArray([effect_probe_path])))
	DirAccess.remove_absolute(effect_probe_path)
	DirAccess.remove_absolute(shared_probe_path)
	if first_signature.is_empty() or second_signature.is_empty():
		fail("cache signature should not be empty for external dependency probe")
		return
	if first_signature == second_signature:
		fail("cache signature should change when an external resource dependency changes")
		return

func test_content_snapshot_cache_signature_tracks_shared_dependency_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache shared dependency contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var root_path := "user://content_snapshot_cache_signature_root_probe.tres"
	var dependency_path := "user://content_snapshot_cache_signature_dependency_probe.tres"
	var dependency_write = FileAccess.open(dependency_path, FileAccess.WRITE)
	if dependency_write == null:
		fail("failed to create cache dependency probe file")
		return
	dependency_write.store_string("[gd_resource type=\"Resource\" load_steps=1 format=3]\n\n[resource]\nvalue = 1\n")
	dependency_write.close()
	var root_write = FileAccess.open(root_path, FileAccess.WRITE)
	if root_write == null:
		DirAccess.remove_absolute(dependency_path)
		fail("failed to create cache root probe file")
		return
	root_write.store_string("[gd_resource type=\"Resource\" load_steps=2 format=3]\n\n[ext_resource type=\"Resource\" path=\"%s\" id=\"1\"]\n\n[resource]\n" % dependency_path)
	root_write.close()
	var first_signature := String(cache._build_signature(PackedStringArray([root_path])))
	var dependency_rewrite = FileAccess.open(dependency_path, FileAccess.WRITE)
	if dependency_rewrite == null:
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(dependency_path)
		fail("failed to rewrite cache dependency probe file")
		return
	dependency_rewrite.store_string("[gd_resource type=\"Resource\" load_steps=1 format=3]\n\n[resource]\nvalue = 2\n")
	dependency_rewrite.close()
	var second_signature := String(cache._build_signature(PackedStringArray([root_path])))
	DirAccess.remove_absolute(root_path)
	DirAccess.remove_absolute(dependency_path)
	if first_signature.is_empty() or second_signature.is_empty():
		fail("cache signature should not be empty for dependency probe")
		return
	if first_signature == second_signature:
		fail("cache signature should change when a referenced shared dependency changes")
		return

func test_content_snapshot_cache_signature_tracks_runtime_registry_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache runtime registry contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var root_path := "user://content_snapshot_cache_root_probe.txt"
	var registry_path := "user://content_snapshot_cache_runtime_registry_probe.json"
	var root_write = FileAccess.open(root_path, FileAccess.WRITE)
	if root_write == null:
		fail("failed to create cache root probe file")
		return
	root_write.store_string("root")
	root_write.close()
	var registry_write = FileAccess.open(registry_path, FileAccess.WRITE)
	if registry_write == null:
		DirAccess.remove_absolute(root_path)
		fail("failed to create runtime registry probe file")
		return
	registry_write.store_string("{\"version\": 1}")
	registry_write.close()
	cache.signature_static_file_paths = PackedStringArray([registry_path])
	cache.signature_static_dir_paths = PackedStringArray()
	var first_signature := String(cache._build_signature(PackedStringArray([root_path])))
	var registry_rewrite = FileAccess.open(registry_path, FileAccess.WRITE)
	if registry_rewrite == null:
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(registry_path)
		fail("failed to rewrite runtime registry probe file")
		return
	registry_rewrite.store_string("{\"version\": 2}")
	registry_rewrite.close()
	var second_signature := String(cache._build_signature(PackedStringArray([root_path])))
	DirAccess.remove_absolute(root_path)
	DirAccess.remove_absolute(registry_path)
	if first_signature.is_empty() or second_signature.is_empty():
		fail("cache signature should not be empty for runtime registry probe")
		return
	if first_signature == second_signature:
		fail("cache signature should change when tracked runtime registry content changes")
		return

func test_content_snapshot_cache_signature_tracks_content_script_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache content script contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var root_path := "user://content_snapshot_cache_script_root_probe.txt"
	var script_dir_path := "res://tmp/content_snapshot_cache_script_probe"
	var script_path := "%s/schema_probe.gd" % script_dir_path
	DirAccess.make_dir_recursive_absolute(script_dir_path)
	var root_write = FileAccess.open(root_path, FileAccess.WRITE)
	if root_write == null:
		fail("failed to create cache script root probe file")
		return
	root_write.store_string("root")
	root_write.close()
	var script_write = FileAccess.open(script_path, FileAccess.WRITE)
	if script_write == null:
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(script_dir_path)
		fail("failed to create content script probe file")
		return
	script_write.store_string("extends RefCounted\n")
	script_write.close()
	cache.signature_static_file_paths = PackedStringArray()
	cache.signature_static_dir_paths = PackedStringArray([script_dir_path])
	var tracked_script_paths_before: Array[String] = cache._dependency_collector.collect_tracked_signature_paths(PackedStringArray([root_path]))
	if not tracked_script_paths_before.has(script_path):
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(script_path)
		DirAccess.remove_absolute(script_dir_path)
		fail("cache signature should track static script path before rewrite: %s" % [tracked_script_paths_before])
		return
	var first_signature := String(cache._build_signature(PackedStringArray([root_path])))
	var script_rewrite = FileAccess.open(script_path, FileAccess.WRITE)
	if script_rewrite == null:
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(script_path)
		DirAccess.remove_absolute(script_dir_path)
		fail("failed to rewrite content script probe file")
		return
	script_rewrite.store_string("extends RefCounted\nclass_name SchemaProbe\n")
	script_rewrite.close()
	var second_signature := String(cache._build_signature(PackedStringArray([root_path])))
	DirAccess.remove_absolute(root_path)
	DirAccess.remove_absolute(script_path)
	DirAccess.remove_absolute(script_dir_path)
	if first_signature.is_empty() or second_signature.is_empty():
		fail("cache signature should not be empty for content script probe")
		return
	if first_signature == second_signature:
		fail("cache signature should change when tracked content script changes: %s" % first_signature)
		return

func test_content_snapshot_cache_signature_tracks_formal_scaffold_inputs_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache formal scaffold contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var file_paths := Array(cache.signature_static_file_paths)
	var dir_paths := Array(cache.signature_static_dir_paths)
	for required_path in [
		"res://config/formal_character_capability_catalog.json",
		"res://src/shared/formal_character_baselines.gd",
		"res://src/shared/formal_character_capability_catalog.gd",
	]:
		if not file_paths.has(required_path):
			fail("cache signature must track formal static file: %s" % required_path)
			return
	for required_dir in [
		"res://config/formal_character_sources",
		"res://src/shared/formal_character_baselines",
	]:
		if not dir_paths.has(required_dir):
			fail("cache signature must track formal static dir: %s" % required_dir)
			return

func test_content_snapshot_cache_signature_tracks_static_json_dirs_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache static json contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var root_path := "user://content_snapshot_cache_static_json_root_probe.txt"
	var static_dir_path := "res://tmp/content_snapshot_cache_static_json_probe"
	var static_json_path := "%s/formal_source_probe.json" % static_dir_path
	DirAccess.make_dir_recursive_absolute(static_dir_path)
	var root_write = FileAccess.open(root_path, FileAccess.WRITE)
	if root_write == null:
		fail("failed to create static json root probe file")
		return
	root_write.store_string("root")
	root_write.close()
	var json_write = FileAccess.open(static_json_path, FileAccess.WRITE)
	if json_write == null:
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(static_dir_path)
		fail("failed to create static json probe file")
		return
	json_write.store_string("{\"version\":1}")
	json_write.close()
	cache.signature_static_file_paths = PackedStringArray()
	cache.signature_static_dir_paths = PackedStringArray([static_dir_path])
	var tracked_static_json_paths_before: Array[String] = cache._dependency_collector.collect_tracked_signature_paths(PackedStringArray([root_path]))
	if not tracked_static_json_paths_before.has(static_json_path):
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(static_json_path)
		DirAccess.remove_absolute(static_dir_path)
		fail("cache signature should track static json path before rewrite: %s" % [tracked_static_json_paths_before])
		return
	var first_signature := String(cache._build_signature(PackedStringArray([root_path])))
	var json_rewrite = FileAccess.open(static_json_path, FileAccess.WRITE)
	if json_rewrite == null:
		DirAccess.remove_absolute(root_path)
		DirAccess.remove_absolute(static_json_path)
		DirAccess.remove_absolute(static_dir_path)
		fail("failed to rewrite static json probe file")
		return
	json_rewrite.store_string("{\"version\":2}")
	json_rewrite.close()
	var second_signature := String(cache._build_signature(PackedStringArray([root_path])))
	DirAccess.remove_absolute(root_path)
	DirAccess.remove_absolute(static_json_path)
	DirAccess.remove_absolute(static_dir_path)
	if first_signature.is_empty() or second_signature.is_empty():
		fail("cache signature should not be empty for static json probe")
		return
	if first_signature == second_signature:
		fail("cache signature should change when tracked static json changes: %s" % first_signature)
		return

func test_content_snapshot_cache_signature_fails_on_missing_static_dir_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var composer = manager_payload.get("composer", null)
	if composer == null:
		fail("content snapshot cache missing static dir contract requires composer handle")
		return
	var cache = composer.shared_content_snapshot_cache()
	if cache == null:
		fail("shared content snapshot cache should be available")
		return
	var root_path := "user://content_snapshot_cache_missing_static_root_probe.txt"
	var root_write = FileAccess.open(root_path, FileAccess.WRITE)
	if root_write == null:
		fail("failed to create cache missing static root probe file")
		return
	root_write.store_string("root")
	root_write.close()
	cache.signature_static_file_paths = PackedStringArray()
	cache.signature_static_dir_paths = PackedStringArray(["res://tmp/content_snapshot_cache_missing_static_dir_probe"])
	var signature := String(cache._build_signature(PackedStringArray([root_path])))
	DirAccess.remove_absolute(root_path)
	if not signature.is_empty():
		fail("cache signature should fail when tracked static dir is missing")
		return
	var signature_error := String(cache._signature_builder.get("last_error_message"))
	if not signature_error.contains("missing content snapshot signature dir"):
		fail("cache signature should expose missing static dir error: %s" % signature_error)
		return

