extends "res://test/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _manifest = FormalCharacterManifestScript.new()
var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _contract_helper = _smoke_helper.contracts()

func test_formal_character_manager_blackbox_contract_matrix() -> void:
	_assert_legacy_result(_test_formal_character_manager_blackbox_contract_matrix(_harness))

func _test_formal_character_manager_blackbox_contract_matrix(harness) -> Dictionary:
	var entries_result: Dictionary = _manifest.build_runtime_entries_result()
	if not bool(entries_result.get("ok", false)):
		return harness.fail_result(str(entries_result.get("error_message", "formal manager blackbox matrix failed to load manifest")))
	var entries: Array = entries_result.get("data", [])
	if entries.is_empty():
		return harness.fail_result("formal manager blackbox matrix requires at least one character")
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var result := _run_character_blackbox_contract(harness, entry, 1801 + entry_index)
		if not bool(result.get("ok", false)):
			return result
	return harness.pass_result()

func _run_character_blackbox_contract(harness, entry: Dictionary, battle_seed: int) -> Dictionary:
	var character_id := String(entry.get("character_id", "")).strip_edges()
	if character_id.is_empty():
		return harness.fail_result("formal manager blackbox matrix entry missing character_id")
	var context := _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var setup_result: Dictionary = sample_factory.build_formal_character_setup_result(character_id)
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("%s blackbox matrix formal setup failed: %s" % [character_id, String(setup_result.get("error_message", "unknown error"))])
	var init_unwrap = _smoke_helper.create_session(
		manager,
		sample_factory,
		battle_seed,
		setup_result.get("data", null),
		"create_session(%s blackbox matrix)" % character_id
	)
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "%s blackbox matrix create_session failed" % character_id)))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var result := _run_first_legal_turns(harness, manager, session_id, character_id, 4)
	if not bool(result.get("ok", false)):
		return result
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(%s blackbox)" % character_id)
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "%s blackbox matrix event log failed" % character_id)))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if events.is_empty():
		return harness.fail_result("%s blackbox matrix event log should not be empty" % character_id)
	if _contract_helper.contains_runtime_id_leak(events):
		return harness.fail_result("%s blackbox matrix event log must stay public-safe" % character_id)
	_smoke_helper.close_session(manager, session_id, "close_session(%s blackbox matrix)" % character_id)
	return harness.pass_result()

func _run_first_legal_turns(harness, manager, session_id: String, character_id: String, max_turns: int) -> Dictionary:
	for turn_index in range(1, max_turns + 1):
		var snapshot_before_result := _validate_public_snapshot(harness, manager, session_id, character_id)
		if not bool(snapshot_before_result.get("ok", false)):
			return snapshot_before_result
		var snapshot_before: Dictionary = snapshot_before_result.get("data", {})
		var p1_actor_public_id := _active_public_id(snapshot_before, "P1")
		var p2_actor_public_id := _active_public_id(snapshot_before, "P2")
		var p1_legal_result := _first_action_result(manager, session_id, "P1", character_id)
		if not bool(p1_legal_result.get("ok", false)):
			return harness.fail_result(str(p1_legal_result.get("error", "%s blackbox matrix missing P1 action" % character_id)))
		var p2_legal_result := _first_action_result(manager, session_id, "P2", character_id)
		if not bool(p2_legal_result.get("ok", false)):
			return harness.fail_result(str(p2_legal_result.get("error", "%s blackbox matrix missing P2 action" % character_id)))
		var turn_result = _smoke_helper.run_turn_result(manager, session_id, {
			"turn_index": turn_index,
			"label": "run_turn(%s blackbox matrix)" % character_id,
			"p1_actor_public_id": p1_actor_public_id,
			"p2_actor_public_id": p2_actor_public_id,
			"p1_action": p1_legal_result.get("data", "wait"),
			"p2_action": p2_legal_result.get("data", "wait"),
			"p1_label": "build_command(P1 first legal)",
			"p2_label": "build_command(P2 first legal)",
		})
		if not bool(turn_result.get("ok", false)):
			return harness.fail_result(str(turn_result.get("error", "%s blackbox matrix run_turn failed" % character_id)))
		var snapshot_result := _validate_public_snapshot(harness, manager, session_id, character_id)
		if not bool(snapshot_result.get("ok", false)):
			return snapshot_result
		var public_snapshot: Dictionary = snapshot_result.get("data", {})
		var battle_result = public_snapshot.get("battle_result", {})
		if battle_result is Dictionary and bool(battle_result.get("finished", false)):
			return harness.pass_result()
	return harness.pass_result()

func _first_action_result(manager, session_id: String, side_id: String, character_id: String) -> Dictionary:
	var legal_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, side_id, "get_legal_actions(%s %s)" % [character_id, side_id])
	if not bool(legal_unwrap.get("ok", false)):
		return {"ok": false, "error": str(legal_unwrap.get("error", "%s %s blackbox legal actions failed" % [character_id, side_id]))}
	var legal_actions = legal_unwrap.get("data", null)
	if legal_actions == null:
		return {"ok": false, "error": "%s %s blackbox legal actions returned null" % [character_id, side_id]}
	if not legal_actions.legal_skill_ids.is_empty():
		return {"ok": true, "data": String(legal_actions.legal_skill_ids[0])}
	if not legal_actions.legal_ultimate_ids.is_empty():
		return {"ok": true, "data": {"action_kind": CommandTypesScript.ULTIMATE, "skill_id": String(legal_actions.legal_ultimate_ids[0])}}
	if not legal_actions.legal_switch_target_public_ids.is_empty():
		return {"ok": true, "data": {"action_kind": CommandTypesScript.SWITCH, "target_public_id": String(legal_actions.legal_switch_target_public_ids[0])}}
	if bool(legal_actions.wait_allowed):
		return {"ok": true, "data": "wait"}
	return {"ok": false, "error": "%s %s blackbox has no selectable action" % [character_id, side_id]}

func _validate_public_snapshot(harness, manager, session_id: String, character_id: String) -> Dictionary:
	var snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(%s blackbox)" % character_id)
	if not bool(snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(snapshot_unwrap.get("error", "%s blackbox matrix snapshot failed" % character_id)))
	var public_snapshot: Dictionary = snapshot_unwrap.get("data", {})
	var shape_error: String = _contract_helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("%s blackbox matrix snapshot malformed: %s" % [character_id, shape_error])
	return {"ok": true, "data": public_snapshot}

func _active_public_id(public_snapshot: Dictionary, side_id: String) -> String:
	for side_snapshot in public_snapshot.get("sides", []):
		if side_snapshot is Dictionary and String(side_snapshot.get("side_id", "")) == side_id:
			return String(side_snapshot.get("active_public_id", ""))
	return "%s-A" % side_id
