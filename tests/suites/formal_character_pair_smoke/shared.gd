extends RefCounted
class_name FormalCharacterPairSmokeShared

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _helper = _smoke_helper.contracts()

func validate_directed_surface_matrix(harness, sample_factory, cases: Array) -> Dictionary:
	var formal_character_ids: PackedStringArray = harness.build_formal_character_ids(sample_factory)
	if formal_character_ids.size() < 2:
		return harness.fail_result("formal pair smoke requires at least two formal characters")
	var known_character_ids := {}
	for raw_character_id in formal_character_ids:
		known_character_ids[String(raw_character_id)] = true
	var expected_pairs := {}
	for left_character_id in formal_character_ids:
		for right_character_id in formal_character_ids:
			if String(left_character_id) == String(right_character_id):
				continue
			expected_pairs[_directed_pair_key(String(left_character_id), String(right_character_id))] = true
	var actual_pairs := {}
	for raw_case_spec in cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair smoke case must be Dictionary")
		var case_spec: Dictionary = raw_case_spec
		var p1_character_id := String(case_spec.get("p1_character_id", "")).strip_edges()
		var p2_character_id := String(case_spec.get("p2_character_id", "")).strip_edges()
		if p1_character_id.is_empty() or p2_character_id.is_empty():
			return harness.fail_result("formal pair smoke case is missing p1/p2 character ids")
		if p1_character_id == p2_character_id:
			return harness.fail_result("formal pair smoke case must be directional and cannot target the same character on both sides")
		if not known_character_ids.has(p1_character_id) or not known_character_ids.has(p2_character_id):
			return harness.fail_result("formal pair smoke case references unknown formal character id")
		var pair_key := _directed_pair_key(p1_character_id, p2_character_id)
		if actual_pairs.has(pair_key):
			return harness.fail_result("formal pair smoke duplicated directed pair coverage: %s" % pair_key)
		actual_pairs[pair_key] = true
	var missing_pairs: Array[String] = []
	for expected_pair_key in expected_pairs.keys():
		if not actual_pairs.has(expected_pair_key):
			missing_pairs.append(String(expected_pair_key))
	missing_pairs.sort()
	if not missing_pairs.is_empty():
		return harness.fail_result("formal pair smoke missing directed pair coverage: %s" % ", ".join(missing_pairs))
	var extra_pairs: Array[String] = []
	for actual_pair_key in actual_pairs.keys():
		if not expected_pairs.has(actual_pair_key):
			extra_pairs.append(String(actual_pair_key))
	extra_pairs.sort()
	if not extra_pairs.is_empty():
		return harness.fail_result("formal pair smoke contains non-matrix directed pair coverage: %s" % ", ".join(extra_pairs))
	return harness.pass_result()

func validate_unordered_interaction_matrix(harness, sample_factory, cases: Array) -> Dictionary:
	var formal_character_ids: PackedStringArray = harness.build_formal_character_ids(sample_factory)
	if formal_character_ids.size() < 2:
		return harness.fail_result("formal pair interaction requires at least two formal characters")
	var known_character_ids := {}
	for raw_character_id in formal_character_ids:
		known_character_ids[String(raw_character_id)] = true
	var expected_pairs := {}
	for left_index in range(formal_character_ids.size()):
		for right_index in range(left_index + 1, formal_character_ids.size()):
			expected_pairs[_unordered_pair_key(
				String(formal_character_ids[left_index]),
				String(formal_character_ids[right_index])
			)] = true
	var actual_pairs := {}
	for raw_case_spec in cases:
		if not (raw_case_spec is Dictionary):
			return harness.fail_result("formal pair interaction case must be Dictionary")
		var case_spec: Dictionary = raw_case_spec
		var character_ids = case_spec.get("character_ids", [])
		if not (character_ids is Array) or character_ids.size() != 2:
			return harness.fail_result("formal pair interaction case must define exactly two character_ids")
		var left_character_id := String(character_ids[0]).strip_edges()
		var right_character_id := String(character_ids[1]).strip_edges()
		if left_character_id.is_empty() or right_character_id.is_empty():
			return harness.fail_result("formal pair interaction case contains empty character_ids")
		if left_character_id == right_character_id:
			return harness.fail_result("formal pair interaction case cannot target the same character twice")
		if not known_character_ids.has(left_character_id) or not known_character_ids.has(right_character_id):
			return harness.fail_result("formal pair interaction case references unknown formal character id")
		if String(case_spec.get("scenario_key", "")).strip_edges().is_empty():
			return harness.fail_result("formal pair interaction case missing scenario_key")
		if String(case_spec.get("matchup_id", "")).strip_edges().is_empty():
			return harness.fail_result("formal pair interaction case missing matchup_id")
		if not _is_positive_whole_number(case_spec.get("battle_seed", null)):
			return harness.fail_result("formal pair interaction case missing positive integer battle_seed")
		var pair_key := _unordered_pair_key(left_character_id, right_character_id)
		actual_pairs[pair_key] = true
	var missing_pairs: Array[String] = []
	for expected_pair_key in expected_pairs.keys():
		if not actual_pairs.has(expected_pair_key):
			missing_pairs.append(String(expected_pair_key))
	missing_pairs.sort()
	if not missing_pairs.is_empty():
		return harness.fail_result("formal pair interaction missing unordered pair coverage: %s" % ", ".join(missing_pairs))
	var extra_pairs: Array[String] = []
	for actual_pair_key in actual_pairs.keys():
		if not expected_pairs.has(actual_pair_key):
			extra_pairs.append(String(actual_pair_key))
	extra_pairs.sort()
	if not extra_pairs.is_empty():
		return harness.fail_result("formal pair interaction contains non-matrix unordered pair coverage: %s" % ", ".join(extra_pairs))
	return harness.pass_result()

func find_case_by_test_name(cases: Array, test_name: String) -> Dictionary:
	for raw_case_spec in cases:
		if not (raw_case_spec is Dictionary):
			continue
		var case_spec: Dictionary = raw_case_spec
		if String(case_spec.get("test_name", "")) == test_name:
			return case_spec
	return {}

func run_surface_case(harness, sample_factory, case_spec: Dictionary) -> Dictionary:
	var context: Dictionary = _smoke_helper.build_context(harness, sample_factory)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var matchup_id := String(case_spec.get("matchup_id", ""))
	var battle_setup_result: Dictionary = context["sample_factory"].build_setup_by_matchup_id_result(matchup_id)
	if not bool(battle_setup_result.get("ok", false)):
		return harness.fail_result("formal pair smoke matchup setup missing: %s (%s)" % [
			matchup_id,
			String(battle_setup_result.get("error_message", "unknown error")),
		])
	var battle_setup = battle_setup_result.get("data", null)
	var battle_seed = case_spec.get("battle_seed", null)
	if not _is_positive_whole_number(battle_seed):
		return harness.fail_result("formal pair smoke case missing positive integer battle_seed")
	var p1_skill_id := String(case_spec.get("p1_skill_id", "")).strip_edges()
	var p2_skill_id := String(case_spec.get("p2_skill_id", "")).strip_edges()
	if p1_skill_id.is_empty() or p2_skill_id.is_empty():
		return harness.fail_result("formal pair smoke case missing skill ids")
	return _run_surface_turn_case(
		harness,
		context["manager"],
		context["sample_factory"],
		int(battle_seed),
		battle_setup,
		p1_skill_id,
		p2_skill_id,
		String(case_spec.get("p1_unit_definition_id", "")),
		String(case_spec.get("p2_unit_definition_id", ""))
	)

func _directed_pair_key(left_character_id: String, right_character_id: String) -> String:
	return "%s->%s" % [left_character_id, right_character_id]

func _unordered_pair_key(left_character_id: String, right_character_id: String) -> String:
	var ordered_pair := [left_character_id, right_character_id]
	ordered_pair.sort()
	return "%s<->%s" % [ordered_pair[0], ordered_pair[1]]

func _is_positive_whole_number(value) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric_value := float(value)
	return numeric_value > 0.0 and is_equal_approx(numeric_value, floor(numeric_value))

func _run_surface_turn_case(
	harness,
	manager,
	sample_factory,
	battle_seed: int,
	battle_setup,
	p1_skill_id: String,
	p2_skill_id: String,
	p1_unit_definition_id: String,
	p2_unit_definition_id: String
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
	if String(p1_snapshot.get("definition_id", "")) != p1_unit_definition_id:
		return harness.fail_result("formal pair smoke P1 definition drifted: expected %s" % p1_unit_definition_id)
	if String(p2_snapshot.get("definition_id", "")) != p2_unit_definition_id:
		return harness.fail_result("formal pair smoke P2 definition drifted: expected %s" % p2_unit_definition_id)
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot(pair)")
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "pair get_event_log_snapshot failed")))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if events.is_empty():
		return harness.fail_result("formal pair smoke event log should not be empty after both formal roles act")
	if _helper.contains_runtime_id_leak(events):
		return harness.fail_result("formal pair smoke event log must stay public-safe")
	if not _helper.event_log_has_public_action_cast(events, "P1-A", p1_unit_definition_id):
		return harness.fail_result("formal pair smoke should expose P1 public action cast")
	if not _helper.event_log_has_public_action_cast(events, "P2-A", p2_unit_definition_id):
		return harness.fail_result("formal pair smoke should expose P2 public action cast")
	var close_unwrap = _smoke_helper.close_session(manager, session_id, "close_session(pair)")
	if not bool(close_unwrap.get("ok", false)):
		return harness.fail_result(str(close_unwrap.get("error", "pair close_session failed")))
	return harness.pass_result()
