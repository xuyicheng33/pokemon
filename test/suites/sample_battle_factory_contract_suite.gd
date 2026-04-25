extends "res://test/support/gdunit_suite_bridge.gd"

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

const MISSING_RUNTIME_REGISTRY_PATH := "res://tests/fixtures/missing_formal_runtime_registry.json"
const MISSING_FORMAL_MATCHUP_CATALOG_PATH := "res://tests/fixtures/missing_formal_matchup_catalog.json"
const INVALID_DEMO_REPLAY_CATALOG_PATH := "res://tests/fixtures/invalid_demo_replay_catalog.json"

var _helper = ManagerContractTestHelperScript.new()



func test_sample_factory_baseline_setup_ignores_formal_runtime_registry_failure() -> void:
	_assert_legacy_result(_test_baseline_setup_ignores_formal_runtime_registry_failure(_harness))

func test_sample_factory_legacy_demo_ignores_formal_runtime_registry_failure() -> void:
	_assert_legacy_result(_test_legacy_demo_ignores_formal_runtime_registry_failure(_harness))

func test_sample_factory_baseline_flow_ignores_formal_matchup_catalog_failure() -> void:
	_assert_legacy_result(_test_baseline_flow_ignores_formal_matchup_catalog_failure(_harness))

func test_sample_factory_available_matchups_surface_contract() -> void:
	_assert_legacy_result(_test_available_matchups_surface_contract(_harness))

func test_sample_factory_available_matchups_surfaces_formal_catalog_failure() -> void:
	_assert_legacy_result(_test_available_matchups_surfaces_formal_catalog_failure(_harness))

func test_sample_factory_baseline_setup_snapshot_ignores_formal_runtime_registry_failure() -> void:
	_assert_legacy_result(_test_baseline_setup_snapshot_ignores_formal_runtime_registry_failure(_harness))

func test_sample_factory_setup_snapshot_invalid_battle_setup_contract() -> void:
	_assert_legacy_result(_test_setup_snapshot_invalid_battle_setup_contract(_harness))

func test_sample_factory_demo_default_profile_contract() -> void:
	_assert_legacy_result(_test_demo_default_profile_contract(_harness))

func test_sample_factory_demo_invalid_default_profile_contract() -> void:
	_assert_legacy_result(_test_demo_invalid_default_profile_contract(_harness))

func test_sample_factory_demo_profile_ids_contract() -> void:
	_assert_legacy_result(_test_demo_profile_ids_contract(_harness))

func test_sample_factory_demo_switch_command_replay_contract() -> void:
	_assert_legacy_result(_test_demo_switch_command_replay_contract(_harness))
func _test_baseline_setup_ignores_formal_runtime_registry_failure(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory_with_overrides(MISSING_RUNTIME_REGISTRY_PATH)
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var sample_setup_result: Dictionary = sample_factory.build_sample_setup_result()
	if not bool(sample_setup_result.get("ok", false)):
		return harness.fail_result("baseline sample setup should not depend on formal runtime registry: %s" % String(sample_setup_result.get("error_message", "unknown error")))
	var formal_setup_result: Dictionary = sample_factory.build_formal_character_setup_result("gojo_satoru")
	var failure = _helper.expect_failure_code(
		formal_setup_result,
		"build_formal_character_setup_result(gojo_satoru)",
		ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
		"formal character runtime registry"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "formal runtime registry failure contract drifted")))
	return harness.pass_result()

func _test_legacy_demo_ignores_formal_runtime_registry_failure(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory_with_overrides(MISSING_RUNTIME_REGISTRY_PATH)
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_result: Dictionary = sample_factory.build_demo_replay_input_for_profile_result(manager, "legacy")
	if not bool(replay_result.get("ok", false)):
		return harness.fail_result("legacy demo should not depend on formal runtime registry: %s" % String(replay_result.get("error_message", "unknown error")))
	return harness.pass_result()

func _test_baseline_flow_ignores_formal_matchup_catalog_failure(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory_with_overrides("", MISSING_FORMAL_MATCHUP_CATALOG_PATH)
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var sample_setup_result: Dictionary = sample_factory.build_sample_setup_result()
	if not bool(sample_setup_result.get("ok", false)):
		return harness.fail_result("baseline sample setup should not depend on formal matchup catalog: %s" % String(sample_setup_result.get("error_message", "unknown error")))
	var legacy_replay_result: Dictionary = sample_factory.build_demo_replay_input_for_profile_result(manager, "legacy")
	if not bool(legacy_replay_result.get("ok", false)):
		return harness.fail_result("legacy demo should not depend on formal matchup catalog: %s" % String(legacy_replay_result.get("error_message", "unknown error")))
	var formal_setup_result: Dictionary = sample_factory.build_formal_character_setup_result("kashimo_hajime")
	var failure = _helper.expect_failure_code(
		formal_setup_result,
		"build_formal_character_setup_result(kashimo_hajime)",
		ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
		"formal character runtime registry"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "formal manifest failure contract drifted")))
	return harness.pass_result()

func _test_available_matchups_surface_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var available_result: Dictionary = sample_factory.available_matchups_result()
	if not bool(available_result.get("ok", false)):
		return harness.fail_result("available_matchups_result should succeed: %s" % String(available_result.get("error_message", "unknown error")))
	var descriptors = available_result.get("data", [])
	if not (descriptors is Array) or descriptors.is_empty():
		return harness.fail_result("available_matchups_result should return a non-empty descriptor array")
	var saw_baseline := false
	var saw_formal := false
	for raw_descriptor in descriptors:
		if not (raw_descriptor is Dictionary):
			return harness.fail_result("available_matchups_result should only return dictionary descriptors")
		var descriptor: Dictionary = raw_descriptor
		if String(descriptor.get("matchup_id", "")).strip_edges().is_empty():
			return harness.fail_result("available_matchups_result descriptor missing matchup_id")
		if typeof(descriptor.get("p1_units", null)) != TYPE_ARRAY or typeof(descriptor.get("p2_units", null)) != TYPE_ARRAY:
			return harness.fail_result("available_matchups_result descriptor should keep p1_units/p2_units arrays")
		if not descriptor.has("test_only"):
			return harness.fail_result("available_matchups_result descriptor should keep test_only field")
		match String(descriptor.get("source", "")):
			"baseline":
				saw_baseline = true
			"formal":
				saw_formal = true
			_:
				return harness.fail_result("available_matchups_result descriptor source drifted: %s" % String(descriptor.get("source", "")))
	if not saw_baseline or not saw_formal:
		return harness.fail_result("available_matchups_result should aggregate both baseline and formal descriptors")
	return harness.pass_result()

func _test_available_matchups_surfaces_formal_catalog_failure(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory_with_overrides("", MISSING_FORMAL_MATCHUP_CATALOG_PATH)
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var available_result: Dictionary = sample_factory.available_matchups_result()
	var failure = _helper.expect_failure_code(
		available_result,
		"available_matchups_result()",
		ErrorCodesScript.INVALID_BATTLE_SETUP,
		"formal"
	)
	if not bool(failure.get("ok", false)):
		return harness.fail_result(str(failure.get("error", "available matchups formal catalog failure contract drifted")))
	return harness.pass_result()

func _test_baseline_setup_snapshot_ignores_formal_runtime_registry_failure(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory_with_overrides(MISSING_RUNTIME_REGISTRY_PATH)
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var sample_setup_result: Dictionary = sample_factory.build_sample_setup_result()
	if not bool(sample_setup_result.get("ok", false)):
		return harness.fail_result("baseline sample setup should build before setup-scoped snapshot verification")
	var snapshot_result: Dictionary = sample_factory.content_snapshot_paths_for_setup_result(sample_setup_result.get("data", null))
	if not bool(snapshot_result.get("ok", false)):
		return harness.fail_result("baseline-only setup snapshot paths should not depend on formal runtime registry: %s" % String(snapshot_result.get("error_message", "unknown error")))
	var full_snapshot_failure = _helper.expect_failure_code(
		sample_factory.content_snapshot_paths_result(),
		"content_snapshot_paths_result()",
		ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
		"formal character runtime registry"
	)
	if not bool(full_snapshot_failure.get("ok", false)):
		return harness.fail_result(str(full_snapshot_failure.get("error", "content snapshot formal registry failure contract drifted")))
	return harness.pass_result()

func _test_setup_snapshot_invalid_battle_setup_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var cases: Array = [
		{
			"label": "missing sides",
			"battle_setup": {},
			"needle": "requires battle_setup.sides",
		},
		{
			"label": "missing unit_definition_ids",
			"battle_setup": {
				"sides": [
					{"side_id": "P1"},
					{"side_id": "P2", "unit_definition_ids": PackedStringArray(["sample_pyron"])},
				],
			},
			"needle": "battle_setup.sides[0].unit_definition_ids",
		},
	]
	for test_case in cases:
		var failure = _helper.expect_failure_code(
			sample_factory.content_snapshot_paths_for_setup_result(test_case.get("battle_setup", null)),
			"content_snapshot_paths_for_setup_result(%s)" % String(test_case.get("label", "invalid battle_setup")),
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			String(test_case.get("needle", ""))
		)
		if not bool(failure.get("ok", false)):
			return harness.fail_result(str(failure.get("error", "sample factory invalid battle_setup contract failed")))
	return harness.pass_result()

func _test_demo_default_profile_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	if sample_factory.default_demo_profile_id() != "kashimo":
		return harness.fail_result("default demo profile should stay pinned to kashimo")
	var default_result: Dictionary = sample_factory.build_demo_replay_input_result(manager)
	var explicit_result: Dictionary = sample_factory.build_demo_replay_input_for_profile_result(manager, "kashimo")
	if not bool(default_result.get("ok", false)) or not bool(explicit_result.get("ok", false)):
		return harness.fail_result("default and explicit kashimo demo replay inputs should both build successfully")
	var default_input = default_result.get("data", null)
	var explicit_input = explicit_result.get("data", null)
	if default_input == null or explicit_input == null:
		return harness.fail_result("demo replay input should not be null")
	if int(default_input.battle_seed) != int(explicit_input.battle_seed):
		return harness.fail_result("default demo profile should reuse the explicit kashimo battle_seed")
	if default_input.command_stream.size() != explicit_input.command_stream.size():
		return harness.fail_result("default demo profile should reuse the explicit kashimo command stream")
	return harness.pass_result()

func _test_demo_invalid_default_profile_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	sample_factory.configure_demo_catalog_path_override(INVALID_DEMO_REPLAY_CATALOG_PATH)
	var default_profile_result: Dictionary = sample_factory.default_demo_profile_id_result()
	if bool(default_profile_result.get("ok", true)):
		return harness.fail_result("invalid demo catalog should fail fast when default_profile_id drifts")
	if String(default_profile_result.get("error_code", "")) != ErrorCodesScript.INVALID_REPLAY_INPUT:
		return harness.fail_result("invalid demo catalog should report invalid_replay_input for bad default_profile_id")
	if String(default_profile_result.get("error_message", "")).find("default_profile_id") == -1:
		return harness.fail_result("invalid demo catalog should mention default_profile_id drift")
	var replay_result: Dictionary = sample_factory.build_demo_replay_input_result(manager)
	if bool(replay_result.get("ok", true)):
		return harness.fail_result("build_demo_replay_input_result should not fall back to kashimo when default_profile_id is invalid")
	if String(replay_result.get("error_message", "")).find("default_profile_id") == -1:
		return harness.fail_result("default demo replay build failure should preserve default_profile_id error")
	return harness.pass_result()

func _test_demo_profile_ids_contract(harness) -> Dictionary:
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var profile_ids_result: Dictionary = sample_factory.demo_profile_ids_result()
	if not bool(profile_ids_result.get("ok", false)):
		return harness.fail_result("demo_profile_ids_result should succeed: %s" % String(profile_ids_result.get("error_message", "unknown error")))
	var profile_ids = profile_ids_result.get("data", [])
	if not (profile_ids is Array) or profile_ids.is_empty():
		return harness.fail_result("demo_profile_ids_result should return a non-empty array")
	var default_profile_id_result: Dictionary = sample_factory.default_demo_profile_id_result()
	if not bool(default_profile_id_result.get("ok", false)):
		return harness.fail_result("default_demo_profile_id_result should succeed: %s" % String(default_profile_id_result.get("error_message", "unknown error")))
	var default_profile_id := String(default_profile_id_result.get("data", "")).strip_edges()
	if String(profile_ids[0]) != default_profile_id:
		return harness.fail_result("demo_profile_ids_result should keep the default profile first")
	var remaining_profile_ids: Array = profile_ids.slice(1)
	var sorted_remaining_profile_ids: Array = remaining_profile_ids.duplicate()
	sorted_remaining_profile_ids.sort()
	if remaining_profile_ids != sorted_remaining_profile_ids:
		return harness.fail_result("demo_profile_ids_result should keep remaining profile ids sorted")
	return harness.pass_result()

func _test_demo_switch_command_replay_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_result: Dictionary = sample_factory.build_demo_replay_input_result(manager)
	if not bool(replay_result.get("ok", false)):
		return harness.fail_result("default demo replay input build failed: %s" % String(replay_result.get("error_message", "unknown error")))
	var replay_input = replay_result.get("data", null)
	if replay_input == null:
		return harness.fail_result("demo replay input should not be null")
	var has_switch := false
	for command_data in replay_input.command_stream:
		if command_data != null and String(command_data.command_type) == "switch":
			has_switch = true
			break
	if not has_switch:
		return harness.fail_result("default demo replay input should contain a switch command")
	var replay_envelope: Dictionary = manager.run_replay(replay_input)
	var replay_unwrap = _helper.unwrap_ok(replay_envelope, "run_replay(sample_factory default demo)")
	if not bool(replay_unwrap.get("ok", false)):
		return harness.fail_result(str(replay_unwrap.get("error", "default demo replay failed")))
	return harness.pass_result()
