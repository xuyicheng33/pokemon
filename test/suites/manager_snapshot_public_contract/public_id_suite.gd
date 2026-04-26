extends "res://test/suites/manager_snapshot_public_contract/base.gd"
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const BattleHeaderSnapshotBuilderScript := preload("res://src/battle_core/turn/battle_header_snapshot_builder.gd")


func test_legal_action_public_id_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var init_result = manager.create_session({
		"battle_seed": 302,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": _harness.build_sample_setup(sample_factory),
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var session_id: String = str(init_unwrap.get("data", {}).get("session_id", ""))
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		fail(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
		return
	var legal_actions = legal_actions_unwrap.get("data", null)
	if legal_actions.actor_public_id != "P1-A":
		fail("legal_action_set actor should expose actor_public_id only")
		return
	if legal_actions.legal_switch_target_public_ids != PackedStringArray(["P1-B", "P1-C"]):
		fail("legal_action_set switch targets should expose public bench ids only")
		return
	var property_names: Array[String] = []
	for property_data in legal_actions.get_property_list():
		property_names.append(str(property_data.get("name", "")))
	if property_names.has("actor_id") or property_names.has("legal_switch_target_ids"):
		fail("legal_action_set should not leak deprecated runtime instance id fields")
		return
	var close_result = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_result.get("ok", false)):
		fail(str(close_result.get("error", "manager close_session failed")))
		return

func test_initial_selection_mp_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var battle_setup = _harness.build_sample_setup(sample_factory)
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_pyron", "sample_mossaur"])
	battle_setup.sides[0].starting_index = 0
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var reference_state = _harness.build_initialized_battle(core, content_index, sample_factory, 903, battle_setup)
	var reference_snapshot = core.service("public_snapshot_builder").build_public_snapshot(reference_state, content_index)
	var expected_p1_snapshot = _helper.find_side_snapshot(reference_snapshot, "P1")
	var expected_legal_actions = core.service("legal_action_service").get_legal_actions(reference_state, "P1", content_index)
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var init_result = manager.create_session({
		"battle_seed": 903,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": battle_setup,
	})
	var init_unwrap = _helper.unwrap_ok(init_result, "create_session")
	if not bool(init_unwrap.get("ok", false)):
		fail(str(init_unwrap.get("error", "manager create_session failed")))
		return
	var init_data: Dictionary = init_unwrap.get("data", {})
	var session_id: String = str(init_data.get("session_id", ""))
	var public_snapshot: Dictionary = init_data.get("public_snapshot", {})
	var p1_snapshot = _helper.find_side_snapshot(public_snapshot, "P1")
	if p1_snapshot.is_empty():
		fail("manager snapshot missing P1 side")
		return
	if int(p1_snapshot.get("active_mp", -1)) != int(expected_p1_snapshot.get("active_mp", -1)):
		fail("create_session should expose the same pre-applied first-turn regen result as the core initializer")
		return
	var legal_actions_unwrap = _helper.unwrap_ok(manager.get_legal_actions(session_id, "P1"), "get_legal_actions")
	if not bool(legal_actions_unwrap.get("ok", false)):
		fail(str(legal_actions_unwrap.get("error", "manager get_legal_actions failed")))
		return
	var legal_actions = legal_actions_unwrap.get("data", null)
	if legal_actions.legal_ultimate_ids != expected_legal_actions.legal_ultimate_ids:
		fail("first-turn legal set should match the core initializer after pre-applied regen")
		return
	var initial_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(initial_log_unwrap.get("ok", false)):
		fail(str(initial_log_unwrap.get("error", "manager get_event_log_snapshot failed")))
		return
	var initial_log_snapshot: Dictionary = initial_log_unwrap.get("data", {})
	for event_snapshot in initial_log_snapshot.get("events", []):
		if String(event_snapshot.get("event_type", "")) == EventTypesScript.EFFECT_RESOURCE_MOD:
			var value_changes: Array = event_snapshot.get("value_changes", [])
			for value_change in value_changes:
				if str(value_change.get("resource_name", "")) == "mp":
					fail("create_session initial event_log should not retroactively append the pre-applied turn_start regen event")
					return
	var after_turn_envelope = manager.run_turn(session_id, [
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}),
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var after_turn_unwrap = _helper.unwrap_ok(after_turn_envelope, "run_turn")
	if not bool(after_turn_unwrap.get("ok", false)):
		fail(str(after_turn_unwrap.get("error", "manager run_turn failed")))
		return
	var after_turn: Dictionary = after_turn_unwrap.get("data", {})
	core.service("turn_loop_controller").run_turn(reference_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var expected_after_snapshot = core.service("public_snapshot_builder").build_public_snapshot(reference_state, content_index)
	var after_snapshot: Dictionary = after_turn.get("public_snapshot", {})
	var after_p1_snapshot = _helper.find_side_snapshot(after_snapshot, "P1")
	var expected_after_p1_snapshot = _helper.find_side_snapshot(expected_after_snapshot, "P1")
	if int(after_p1_snapshot.get("active_mp", -1)) != int(expected_after_p1_snapshot.get("active_mp", -1)):
		fail("first run_turn must not apply turn_start regen twice or drift from the core path")
		return
	var close_result = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_result.get("ok", false)):
		fail(str(close_result.get("error", "manager close_session failed")))
		return

func test_selection_adapters_public_id_contract() -> void:
	var player_payload = PlayerSelectionAdapterScript.new().build_player_payload({
		"command_type": CommandTypesScript.SWITCH,
		"target_public_id": "P1-B",
	})
	if player_payload.get("target_public_id", "") != "P1-B":
		fail("PlayerSelectionAdapter should preserve target_public_id")
		return
	if player_payload.has("target_unit_id"):
		fail("PlayerSelectionAdapter should not leak target_unit_id")
		return

func test_validator_internal_id_backfill_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 303)
	var actor_unit = battle_state.get_unit_by_public_id("P1-A")
	var target_unit = battle_state.get_unit_by_public_id("P1-B")
	if actor_unit == null or target_unit == null:
		fail("validator backfill test missing units")
		return
	var command = core.service("command_builder").build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SWITCH,
		"command_source": "resource_auto",
		"side_id": "P1",
		"actor_id": actor_unit.unit_instance_id,
		"target_unit_id": target_unit.unit_instance_id,
	})
	if not core.service("command_validator").validate_command(command, battle_state, content_index):
		fail("internal switch command using runtime ids should remain valid")
		return
	if command.actor_public_id != "P1-A" or command.target_public_id != "P1-B":
		fail("validator should backfill public ids when internal runtime ids are supplied")
		return

func test_field_creator_public_id_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 3042)
	var field_state := FieldStateScript.new()
	field_state.field_def_id = "test_private_creator_field"
	field_state.instance_id = "field_instance_private_creator"
	field_state.creator = "runtime_private_creator"
	field_state.remaining_turns = 2
	battle_state.field_state = field_state
	var public_snapshot = PublicSnapshotBuilderScript.new().build_public_snapshot(battle_state, content_index)
	var header_snapshot = BattleHeaderSnapshotBuilderScript.build_header_snapshot(battle_state, content_index)
	var public_field: Dictionary = public_snapshot.get("field", {})
	var header_field: Dictionary = header_snapshot.get("initial_field", {})
	if public_field.get("creator_public_id", "__missing__") != null:
		fail("public snapshot field creator must resolve to public_id or null")
		return
	if header_field.get("creator_public_id", "__missing__") != null:
		fail("header snapshot field creator must resolve to public_id or null")
		return
	if str(public_field.get("creator_public_id", "")) == "runtime_private_creator":
		fail("public snapshot field creator must not fall back to raw runtime/source id")
		return
	if str(header_field.get("creator_public_id", "")) == "runtime_private_creator":
		fail("header snapshot field creator must not fall back to raw runtime/source id")
		return

