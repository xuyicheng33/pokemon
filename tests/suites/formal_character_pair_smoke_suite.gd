extends RefCounted
class_name FormalCharacterPairSmokeSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = null
var _helper = null

func register_tests(runner, failures: Array[String], harness) -> void:
	_ensure_helpers()
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		runner.run_test("formal_pair_smoke_sample_factory_contract", failures, Callable(self, "_test_sample_factory_contract").bind(harness))
		return
	runner.run_test(
		"formal_pair_smoke_matrix_contract",
		failures,
		Callable(self, "_test_pair_matrix_contract").bind(harness, sample_factory)
	)
	runner.run_test("formal_pair_gojo_vs_sukuna_manager_smoke_contract", failures, Callable(self, "_test_named_pair_case").bind(harness, sample_factory, "formal_pair_gojo_vs_sukuna_manager_smoke_contract"))
	runner.run_test("formal_pair_gojo_vs_kashimo_manager_smoke_contract", failures, Callable(self, "_test_named_pair_case").bind(harness, sample_factory, "formal_pair_gojo_vs_kashimo_manager_smoke_contract"))
	runner.run_test("formal_pair_gojo_vs_obito_manager_smoke_contract", failures, Callable(self, "_test_named_pair_case").bind(harness, sample_factory, "formal_pair_gojo_vs_obito_manager_smoke_contract"))
	runner.run_test("formal_pair_sukuna_vs_kashimo_manager_smoke_contract", failures, Callable(self, "_test_named_pair_case").bind(harness, sample_factory, "formal_pair_sukuna_vs_kashimo_manager_smoke_contract"))
	runner.run_test("formal_pair_sukuna_vs_obito_manager_smoke_contract", failures, Callable(self, "_test_named_pair_case").bind(harness, sample_factory, "formal_pair_sukuna_vs_obito_manager_smoke_contract"))
	runner.run_test("formal_pair_kashimo_vs_obito_manager_smoke_contract", failures, Callable(self, "_test_named_pair_case").bind(harness, sample_factory, "formal_pair_kashimo_vs_obito_manager_smoke_contract"))

func _ensure_helpers() -> void:
	if _smoke_helper != null and _helper != null:
		return
	_smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
	_helper = _smoke_helper.contracts()

func _test_sample_factory_contract(harness) -> Dictionary:
	return harness.fail_result("SampleBattleFactory init failed")

func _test_pair_matrix_contract(harness, sample_factory) -> Dictionary:
	var formal_character_ids: PackedStringArray = sample_factory.formal_character_ids()
	if formal_character_ids.size() < 2:
		return harness.fail_result("formal pair smoke requires at least two formal characters")
	var known_ids := {}
	for definition_id in formal_character_ids:
		known_ids[String(definition_id)] = true
	var expected_pairs := {}
	for left_index in range(formal_character_ids.size()):
		for right_index in range(left_index + 1, formal_character_ids.size()):
			var expected_pair_key := _pair_key(String(formal_character_ids[left_index]), String(formal_character_ids[right_index]))
			expected_pairs[expected_pair_key] = true
	var actual_pairs := {}
	for case_spec in sample_factory.formal_pair_smoke_cases():
		var p1_definition_id := String(case_spec.get("p1_definition_id", ""))
		var p2_definition_id := String(case_spec.get("p2_definition_id", ""))
		if p1_definition_id.is_empty() or p2_definition_id.is_empty():
			return harness.fail_result("formal pair smoke case is missing p1/p2 definition ids")
		if not known_ids.has(p1_definition_id) or not known_ids.has(p2_definition_id):
			return harness.fail_result("formal pair smoke case references unknown formal character definition")
		var pair_key := _pair_key(p1_definition_id, p2_definition_id)
		if actual_pairs.has(pair_key):
			return harness.fail_result("formal pair smoke duplicated pair coverage: %s" % pair_key)
		actual_pairs[pair_key] = true
	var missing_pairs: Array[String] = []
	for expected_pair_key in expected_pairs.keys():
		if not actual_pairs.has(expected_pair_key):
			missing_pairs.append(String(expected_pair_key))
	missing_pairs.sort()
	if not missing_pairs.is_empty():
		return harness.fail_result("formal pair smoke missing pair coverage: %s" % ", ".join(missing_pairs))
	var extra_pairs: Array[String] = []
	for actual_pair_key in actual_pairs.keys():
		if not expected_pairs.has(actual_pair_key):
			extra_pairs.append(String(actual_pair_key))
	extra_pairs.sort()
	if not extra_pairs.is_empty():
		return harness.fail_result("formal pair smoke contains non-matrix pair coverage: %s" % ", ".join(extra_pairs))
	return harness.pass_result()

func _test_named_pair_case(harness, sample_factory, test_name: String) -> Dictionary:
	var case_spec := _find_pair_case(sample_factory, test_name)
	if case_spec.is_empty():
		return harness.fail_result("formal pair smoke missing case_spec for %s" % test_name)
	return _test_pair_case(harness, case_spec)

func _find_pair_case(sample_factory, test_name: String) -> Dictionary:
	for raw_case_spec in sample_factory.formal_pair_smoke_cases():
		var case_spec: Dictionary = raw_case_spec
		if String(case_spec.get("test_name", "")) == test_name:
			return case_spec
	return {}

func _test_pair_case(harness, case_spec: Dictionary) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var matchup_id := String(case_spec.get("matchup_id", ""))
	var battle_setup = context["sample_factory"].build_setup_by_matchup_id(matchup_id)
	if battle_setup == null:
		return harness.fail_result("formal pair smoke matchup setup missing: %s" % matchup_id)
	return _run_pair_case(
		harness,
		context["manager"],
		context["sample_factory"],
		int(case_spec.get("battle_seed", 0)),
		battle_setup,
		String(case_spec.get("p1_skill_id", "")),
		String(case_spec.get("p2_skill_id", "")),
		String(case_spec.get("p1_definition_id", "")),
		String(case_spec.get("p2_definition_id", ""))
	)

func _pair_key(left_definition_id: String, right_definition_id: String) -> String:
	var normalized_ids := [left_definition_id, right_definition_id]
	normalized_ids.sort()
	return "%s::%s" % [String(normalized_ids[0]), String(normalized_ids[1])]

func _run_pair_case(
	harness,
	manager,
	sample_factory,
	battle_seed: int,
	battle_setup,
	p1_skill_id: String,
	p2_skill_id: String,
	p1_definition_id: String,
	p2_definition_id: String
) -> Dictionary:
	var init_unwrap = _smoke_helper.create_session(manager, sample_factory, battle_seed, battle_setup, "create_session(pair)")
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "pair create_session failed")))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var p1_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions(P1)")
	if not bool(p1_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(p1_actions_unwrap.get("error", "pair get_legal_actions P1 failed")))
	var p2_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P2"), "get_legal_actions(P2)")
	if not bool(p2_actions_unwrap.get("ok", false)):
		return harness.fail_result(str(p2_actions_unwrap.get("error", "pair get_legal_actions P2 failed")))
	var p1_actions = p1_actions_unwrap.get("data", null)
	var p2_actions = p2_actions_unwrap.get("data", null)
	if String(p1_actions.actor_public_id) != "P1-A" or String(p2_actions.actor_public_id) != "P2-A":
		return harness.fail_result("formal pair smoke should expose stable actor_public_id on both sides")
	if not p1_actions.legal_skill_ids.has(p1_skill_id):
		return harness.fail_result("formal pair smoke P1 should expose %s" % p1_skill_id)
	if not p2_actions.legal_skill_ids.has(p2_skill_id):
		return harness.fail_result("formal pair smoke P2 should expose %s" % p2_skill_id)
	var p1_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": p1_skill_id,
	}), "build_command(P1)")
	if not bool(p1_command.get("ok", false)):
		return harness.fail_result(str(p1_command.get("error", "pair build_command P1 failed")))
	var p2_command = _helper.unwrap_ok(manager.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
		"skill_id": p2_skill_id,
	}), "build_command(P2)")
	if not bool(p2_command.get("ok", false)):
		return harness.fail_result(str(p2_command.get("error", "pair build_command P2 failed")))
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		p1_command.get("data", null),
		p2_command.get("data", null),
	]), "run_turn(pair)")
	if not bool(run_turn_unwrap.get("ok", false)):
		return harness.fail_result(str(run_turn_unwrap.get("error", "pair run_turn failed")))
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot(pair)")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(public_snapshot_unwrap.get("error", "pair get_public_snapshot failed")))
	var public_snapshot: Dictionary = public_snapshot_unwrap.get("data", {})
	var shape_error: String = _helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("formal pair smoke public snapshot malformed: %s" % shape_error)
	var p1_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	var p2_snapshot: Dictionary = _helper.find_unit_snapshot(public_snapshot, "P2", "P2-A")
	if String(p1_snapshot.get("definition_id", "")) != p1_definition_id:
		return harness.fail_result("formal pair smoke P1 definition drifted: expected %s" % p1_definition_id)
	if String(p2_snapshot.get("definition_id", "")) != p2_definition_id:
		return harness.fail_result("formal pair smoke P2 definition drifted: expected %s" % p2_definition_id)
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(pair)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "pair get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if events.is_empty():
		return harness.fail_result("formal pair smoke event log should not be empty after both formal roles act")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("formal pair smoke event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", p1_definition_id):
		return harness.fail_result("formal pair smoke should expose P1 public action cast")
	if not _helper.event_log_has_public_action_cast(events, "P2-A", p2_definition_id):
		return harness.fail_result("formal pair smoke should expose P2 public action cast")
	var close_unwrap = _smoke_helper.close_session(manager, session_id, "close_session(pair)")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "pair close_session failed")))
	return harness.pass_result()
