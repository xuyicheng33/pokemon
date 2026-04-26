extends "res://tests/support/gdunit_suite_bridge.gd"

const FormalCharacterManifestScript := preload("res://src/shared/formal_character_manifest.gd")
const FormalCharacterManagerSmokeHelperScript := preload("res://tests/support/formal_character_manager_smoke_helper.gd")

var _manifest = FormalCharacterManifestScript.new()
var _smoke_helper = FormalCharacterManagerSmokeHelperScript.new()
var _contract_helper = _smoke_helper.contracts()

func test_formal_character_manager_public_contract_matrix() -> void:
	var entries_result: Dictionary = _manifest.build_delivery_entries_result()
	if not bool(entries_result.get("ok", false)):
		fail(str(entries_result.get("error_message", "formal manager public matrix failed to load manifest")))
		return
	var entries: Array = entries_result.get("data", [])
	if entries.is_empty():
		fail("formal manager public matrix requires at least one character")
		return
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var result := _run_character_public_contract(_harness, entry, 1701 + entry_index)
		if not bool(result.get("ok", false)):
			var __legacy_result = result
			if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
				fail(str(__legacy_result.get("error", "unknown error")))
			return


func _run_character_public_contract(harness, entry: Dictionary, battle_seed: int) -> Dictionary:
	var character_id := String(entry.get("character_id", "")).strip_edges()
	var surface_skill_id := String(entry.get("surface_smoke_skill_id", "")).strip_edges()
	if character_id.is_empty() or surface_skill_id.is_empty():
		return harness.fail_result("formal manager public matrix entry missing character_id or surface_smoke_skill_id")
	var context := _smoke_helper.build_context(harness)
	if context.has("error"):
		return harness.fail_result(str(context["error"]))
	var manager = context["manager"]
	var sample_factory = context["sample_factory"]
	var setup_result: Dictionary = sample_factory.build_formal_character_setup_result(character_id)
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("%s formal setup failed: %s" % [character_id, String(setup_result.get("error_message", "unknown error"))])
	var init_unwrap = _smoke_helper.create_session(
		manager,
		sample_factory,
		battle_seed,
		setup_result.get("data", null),
		"create_session(%s public matrix)" % character_id
	)
	if not bool(init_unwrap.get("ok", false)):
		return harness.fail_result(str(init_unwrap.get("error", "%s public matrix create_session failed" % character_id)))
	var session_id := String(init_unwrap.get("data", {}).get("session_id", ""))
	var snapshot_result := _validate_public_snapshot(harness, manager, session_id, character_id)
	if not bool(snapshot_result.get("ok", false)):
		return snapshot_result
	var legal_unwrap = _smoke_helper.get_legal_actions_result(manager, session_id, "P1", "get_legal_actions(%s)" % character_id)
	if not bool(legal_unwrap.get("ok", false)):
		return harness.fail_result(str(legal_unwrap.get("error", "%s public matrix get_legal_actions failed" % character_id)))
	var legal_actions = legal_unwrap.get("data", null)
	if not _legal_actions_include_skill(legal_actions, surface_skill_id):
		return harness.fail_result("%s public matrix should expose surface smoke skill: %s" % [character_id, surface_skill_id])
	var turn_result = _smoke_helper.run_turn_result(manager, session_id, {
		"turn_index": 1,
		"label": "run_turn(%s public matrix)" % character_id,
		"p1_action": surface_skill_id,
		"p2_action": "wait",
		"p1_label": "build_command(%s)" % surface_skill_id,
		"p2_label": "build_command(wait)",
	})
	if not bool(turn_result.get("ok", false)):
		return harness.fail_result(str(turn_result.get("error", "%s public matrix run_turn failed" % character_id)))
	var event_log_unwrap = _smoke_helper.get_event_log_result(manager, session_id, "get_event_log_snapshot(%s)" % character_id)
	if not bool(event_log_unwrap.get("ok", false)):
		return harness.fail_result(str(event_log_unwrap.get("error", "%s public matrix event log failed" % character_id)))
	var events: Array = event_log_unwrap.get("data", {}).get("events", [])
	if events.is_empty():
		return harness.fail_result("%s public matrix event log should not be empty" % character_id)
	if _contract_helper.contains_runtime_id_leak(events):
		return harness.fail_result("%s public matrix event log must stay public-safe" % character_id)
	_smoke_helper.close_session(manager, session_id, "close_session(%s public matrix)" % character_id)
	return harness.pass_result()

func _validate_public_snapshot(harness, manager, session_id: String, character_id: String) -> Dictionary:
	var snapshot_unwrap = _smoke_helper.get_public_snapshot_result(manager, session_id, "get_public_snapshot(%s)" % character_id)
	if not bool(snapshot_unwrap.get("ok", false)):
		return harness.fail_result(str(snapshot_unwrap.get("error", "%s public matrix snapshot failed" % character_id)))
	var public_snapshot: Dictionary = snapshot_unwrap.get("data", {})
	var shape_error: String = _contract_helper.validate_snapshot_shape(public_snapshot)
	if not shape_error.is_empty():
		return harness.fail_result("%s public matrix snapshot malformed: %s" % [character_id, shape_error])
	var actor_snapshot: Dictionary = _contract_helper.find_unit_snapshot(public_snapshot, "P1", "P1-A")
	if actor_snapshot.is_empty():
		return harness.fail_result("%s public matrix missing P1-A public snapshot" % character_id)
	return harness.pass_result()

func _legal_actions_include_skill(legal_actions, skill_id: String) -> bool:
	if legal_actions == null:
		return false
	return legal_actions.legal_skill_ids.has(skill_id) or legal_actions.legal_ultimate_ids.has(skill_id)
