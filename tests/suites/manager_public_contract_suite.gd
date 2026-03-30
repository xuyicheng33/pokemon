extends RefCounted
class_name ManagerPublicContractSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("full_open_public_snapshot_contract", failures, Callable(self, "_test_full_open_public_snapshot_contract").bind(harness))
	runner.run_test("visibility_mode_runtime_decoupled_contract", failures, Callable(self, "_test_visibility_mode_runtime_decoupled_contract").bind(harness))
	runner.run_test("legal_action_public_id_contract", failures, Callable(self, "_test_legal_action_public_id_contract").bind(harness))
	runner.run_test("initial_selection_mp_contract", failures, Callable(self, "_test_initial_selection_mp_contract").bind(harness))
	runner.run_test("selection_adapters_public_id_contract", failures, Callable(self, "_test_selection_adapters_public_id_contract").bind(harness))
	runner.run_test("validator_internal_id_backfill_contract", failures, Callable(self, "_test_validator_internal_id_backfill_contract").bind(harness))
	runner.run_test("event_log_snapshot_public_contract", failures, Callable(self, "_test_event_log_snapshot_public_contract").bind(harness))

func _test_full_open_public_snapshot_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")

	var init_result = manager.create_session({
		"battle_seed": 301,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": sample_factory.build_sample_setup(),
	})
	if init_result == null:
		return harness.fail_result("manager create_session returned null")
	var session_id: String = str(init_result.get("session_id", ""))
	if session_id.is_empty():
		return harness.fail_result("manager create_session missing session_id")
	var public_snapshot = init_result.get("public_snapshot", null)
	if typeof(public_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("manager create_session missing public_snapshot")
	if not public_snapshot.has("visibility_mode") or str(public_snapshot["visibility_mode"]) != "prototype_full_open":
		return harness.fail_result("public_snapshot visibility_mode should be prototype_full_open")
	if not public_snapshot.has("field") or typeof(public_snapshot["field"]) != TYPE_DICTIONARY:
		return harness.fail_result("public_snapshot should include field snapshot")
	var field_snapshot: Dictionary = public_snapshot["field"]
	if not field_snapshot.has("field_kind") or not field_snapshot.has("creator_side_id"):
		return harness.fail_result("field snapshot should expose field_kind and creator_side_id")
	if not public_snapshot.has("sides") or public_snapshot["sides"].size() != 2:
		return harness.fail_result("public_snapshot should include 2 sides")
	for side_snapshot in public_snapshot["sides"]:
		if typeof(side_snapshot) != TYPE_DICTIONARY:
			return harness.fail_result("side snapshot should be Dictionary")
		if not side_snapshot.has("active_public_id") or not side_snapshot.has("active_hp") or not side_snapshot.has("active_mp"):
			return harness.fail_result("legacy active fields missing in side snapshot")
		if not side_snapshot.has("bench_public_ids") or not side_snapshot.has("team_units"):
			return harness.fail_result("side snapshot missing bench/team fields")
		if side_snapshot["team_units"].size() != 3:
			return harness.fail_result("team_units should include 3 entries per side")
		for unit_snapshot in side_snapshot["team_units"]:
			if typeof(unit_snapshot) != TYPE_DICTIONARY:
				return harness.fail_result("team unit snapshot should be Dictionary")
			if typeof(unit_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
				return harness.fail_result("team unit snapshot missing combat_type_ids")

	var prebattle_public_teams = init_result.get("prebattle_public_teams", null)
	if typeof(prebattle_public_teams) != TYPE_ARRAY or prebattle_public_teams.size() != 2:
		return harness.fail_result("create_session should expose prebattle_public_teams")
	if prebattle_public_teams != public_snapshot.get("prebattle_public_teams", []):
		return harness.fail_result("prebattle_public_teams should equal snapshot payload")
	var p1_prebattle_units: Array = prebattle_public_teams[0].get("units", [])
	if p1_prebattle_units.is_empty():
		return harness.fail_result("prebattle_public_teams should include unit payloads")
	var p1_lead_snapshot = p1_prebattle_units[0]
	if typeof(p1_lead_snapshot.get("combat_type_ids", null)) != TYPE_PACKED_STRING_ARRAY:
		return harness.fail_result("prebattle unit snapshot missing combat_type_ids")
	if p1_lead_snapshot["combat_type_ids"] != PackedStringArray(["fire"]):
		return harness.fail_result("prebattle unit combat_type_ids should expose sample fire typing")
	var snapshot_after_init = manager.get_public_snapshot(session_id)
	if snapshot_after_init.get("prebattle_public_teams", []).size() != 2:
		return harness.fail_result("get_public_snapshot should keep prebattle_public_teams")
	if _helper.contains_key_recursive(public_snapshot, "unit_instance_id"):
		return harness.fail_result("public_snapshot leaks unit_instance_id")
	if _helper.contains_key_recursive(prebattle_public_teams, "unit_instance_id"):
		return harness.fail_result("prebattle_public_teams leaks unit_instance_id")
	manager.close_session(session_id)
	return harness.pass_result()

func _test_visibility_mode_runtime_decoupled_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var format_config = content_index.battle_formats.get("prototype_full_open", null)
	if format_config == null:
		return harness.fail_result("missing sample battle format")
	format_config.visibility_mode = "test_custom_visibility_mode"
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 406)
	if battle_state.format_id != "prototype_full_open":
		return harness.fail_result("battle_state.format_id should remain battle format id")
	if battle_state.visibility_mode != "test_custom_visibility_mode":
		return harness.fail_result("battle_state.visibility_mode should come from BattleFormatConfig.visibility_mode")
	var stable_state = battle_state.to_stable_dict()
	if str(stable_state.get("visibility_mode", "")) != "test_custom_visibility_mode":
		return harness.fail_result("BattleState.to_stable_dict should serialize visibility_mode from runtime field")
	var public_snapshot = core.public_snapshot_builder.build_public_snapshot(battle_state, content_index)
	if str(public_snapshot.get("visibility_mode", "")) != "test_custom_visibility_mode":
		return harness.fail_result("public snapshot should read visibility_mode from battle_state.visibility_mode")
	var header_event = null
	for log_event in core.battle_logger.event_log:
		if log_event.event_type == EventTypesScript.SYSTEM_BATTLE_HEADER:
			header_event = log_event
			break
	if header_event == null:
		return harness.fail_result("missing system:battle_header log")
	if typeof(header_event.header_snapshot) != TYPE_DICTIONARY:
		return harness.fail_result("header_snapshot should be Dictionary")
	if str(header_event.header_snapshot.get("visibility_mode", "")) != "test_custom_visibility_mode":
		return harness.fail_result("header_snapshot.visibility_mode should read battle_state.visibility_mode")
	return harness.pass_result()

func _test_legal_action_public_id_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var init_result = manager.create_session({
		"battle_seed": 302,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": sample_factory.build_sample_setup(),
	})
	var session_id: String = str(init_result.get("session_id", ""))
	var legal_actions = manager.get_legal_actions(session_id, "P1")
	if legal_actions == null:
		return harness.fail_result("manager get_legal_actions returned null")
	if legal_actions.actor_public_id != "P1-A":
		return harness.fail_result("legal_action_set actor should expose actor_public_id only")
	if legal_actions.legal_switch_target_public_ids != PackedStringArray(["P1-B", "P1-C"]):
		return harness.fail_result("legal_action_set switch targets should expose public bench ids only")
	var property_names: Array[String] = []
	for property_data in legal_actions.get_property_list():
		property_names.append(str(property_data.get("name", "")))
	if property_names.has("actor_id") or property_names.has("legal_switch_target_ids"):
		return harness.fail_result("legal_action_set should not leak deprecated runtime instance id fields")
	manager.close_session(session_id)
	return harness.pass_result()

func _test_initial_selection_mp_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var battle_setup = sample_factory.build_sample_setup()
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_pyron", "sample_mossaur"])
	battle_setup.sides[0].starting_index = 0
	var content_index = harness.build_loaded_content_index(sample_factory)
	var reference_state = harness.build_initialized_battle(core, content_index, sample_factory, 903, battle_setup)
	var reference_snapshot = core.public_snapshot_builder.build_public_snapshot(reference_state, content_index)
	var expected_p1_snapshot = _helper.find_side_snapshot(reference_snapshot, "P1")
	var expected_legal_actions = core.legal_action_service.get_legal_actions(reference_state, "P1", content_index)

	var init_result = manager.create_session({
		"battle_seed": 903,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": battle_setup,
	})
	var session_id: String = str(init_result.get("session_id", ""))
	var public_snapshot: Dictionary = init_result.get("public_snapshot", {})
	var p1_snapshot = _helper.find_side_snapshot(public_snapshot, "P1")
	if p1_snapshot.is_empty():
		return harness.fail_result("manager snapshot missing P1 side")
	if int(p1_snapshot.get("active_mp", -1)) != int(expected_p1_snapshot.get("active_mp", -1)):
		return harness.fail_result("create_session should expose the same pre-applied first-turn regen result as the core initializer")
	var legal_actions = manager.get_legal_actions(session_id, "P1")
	if legal_actions.legal_ultimate_ids != expected_legal_actions.legal_ultimate_ids:
		return harness.fail_result("first-turn legal set should match the core initializer after pre-applied regen")
	var initial_log_snapshot: Dictionary = manager.get_event_log_snapshot(session_id)
	for event_snapshot in initial_log_snapshot.get("events", []):
		if String(event_snapshot.get("event_type", "")) == EventTypesScript.EFFECT_RESOURCE_MOD:
			var value_changes: Array = event_snapshot.get("value_changes", [])
			for value_change in value_changes:
				if str(value_change.get("resource_name", "")) == "mp":
					return harness.fail_result("create_session initial event_log should not retroactively append the pre-applied turn_start regen event")

	var after_turn = manager.run_turn(session_id, [
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
	core.turn_loop_controller.run_turn(reference_state, content_index, [
		core.command_builder.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}),
		core.command_builder.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var expected_after_snapshot = core.public_snapshot_builder.build_public_snapshot(reference_state, content_index)
	var after_snapshot: Dictionary = after_turn.get("public_snapshot", {})
	var after_p1_snapshot = _helper.find_side_snapshot(after_snapshot, "P1")
	var expected_after_p1_snapshot = _helper.find_side_snapshot(expected_after_snapshot, "P1")
	if int(after_p1_snapshot.get("active_mp", -1)) != int(expected_after_p1_snapshot.get("active_mp", -1)):
		return harness.fail_result("first run_turn must not apply turn_start regen twice or drift from the core path")
	manager.close_session(session_id)
	return harness.pass_result()

func _test_selection_adapters_public_id_contract(_harness) -> Dictionary:
	var player_payload = PlayerSelectionAdapterScript.new().build_player_payload({
		"command_type": CommandTypesScript.SWITCH,
		"target_public_id": "P1-B",
	})
	if player_payload.get("target_public_id", "") != "P1-B":
		return {"ok": false, "error": "PlayerSelectionAdapter should preserve target_public_id"}
	if player_payload.has("target_unit_id"):
		return {"ok": false, "error": "PlayerSelectionAdapter should not leak target_unit_id"}
	return {"ok": true}

func _test_validator_internal_id_backfill_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 303)
	var actor_unit = battle_state.get_unit_by_public_id("P1-A")
	var target_unit = battle_state.get_unit_by_public_id("P1-B")
	if actor_unit == null or target_unit == null:
		return harness.fail_result("validator backfill test missing units")
	var command = core.command_builder.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SWITCH,
		"command_source": "resource_auto",
		"side_id": "P1",
		"actor_id": actor_unit.unit_instance_id,
		"target_unit_id": target_unit.unit_instance_id,
	})
	if not core.command_validator.validate_command(command, battle_state, content_index):
		return harness.fail_result("internal switch command using runtime ids should remain valid")
	if command.actor_public_id != "P1-A" or command.target_public_id != "P1-B":
		return harness.fail_result("validator should backfill public ids when internal runtime ids are supplied")
	return harness.pass_result()

func _test_event_log_snapshot_public_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var init_result = manager.create_session({
		"battle_seed": 304,
		"content_snapshot_paths": sample_factory.content_snapshot_paths(),
		"battle_setup": sample_factory.build_gojo_vs_sukuna_setup(),
	})
	var session_id: String = str(init_result.get("session_id", ""))
	var initial_snapshot: Dictionary = manager.get_event_log_snapshot(session_id)
	var initial_events: Array = initial_snapshot.get("events", [])
	var initial_total_size: int = int(initial_snapshot.get("total_size", -1))
	if initial_total_size != initial_events.size():
		return harness.fail_result("get_event_log_snapshot total_size should match full snapshot size")
	var turn_result: Dictionary = manager.run_turn(session_id, [
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "gojo_ao",
		}),
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sukuna_kai",
		}),
	])
	if typeof(turn_result.get("public_snapshot", null)) != TYPE_DICTIONARY:
		return harness.fail_result("run_turn should keep returning public_snapshot after event log API addition")
	var delta_snapshot: Dictionary = manager.get_event_log_snapshot(session_id, initial_total_size)
	var delta_events: Array = delta_snapshot.get("events", [])
	if delta_events.is_empty():
		return harness.fail_result("event log delta should include turn events after run_turn")
	var action_cast_event_found := false
	var public_value_change_shape_checked := false
	for event_snapshot in delta_events:
		if typeof(event_snapshot) != TYPE_DICTIONARY:
			return harness.fail_result("event log snapshot entries must be Dictionary")
		if _helper.contains_any_key_recursive(event_snapshot, PackedStringArray([
			"actor_id",
			"source_instance_id",
			"target_instance_id",
			"killer_id",
			"entity_id",
		])):
			return harness.fail_result("public event log snapshot must not leak runtime ids")
		if event_snapshot.has("actor_public_id") and event_snapshot.has("actor_definition_id") and event_snapshot.has("target_public_id") and event_snapshot.has("target_definition_id") and event_snapshot.has("killer_public_id") and event_snapshot.has("killer_definition_id"):
			if typeof(event_snapshot.get("value_changes", null)) != TYPE_ARRAY:
				return harness.fail_result("public event log snapshot should keep value_changes as Array")
			for value_change in event_snapshot.get("value_changes", []):
				if typeof(value_change) != TYPE_DICTIONARY:
					return harness.fail_result("public event value_change must be Dictionary")
				if not value_change.has("entity_public_id") or not value_change.has("entity_definition_id"):
					return harness.fail_result("public event value_changes should expose only public-safe entity ids")
			public_value_change_shape_checked = true
		if String(event_snapshot.get("event_type", "")) == EventTypesScript.ACTION_CAST \
		and str(event_snapshot.get("actor_public_id", "")) == "P1-A" \
		and str(event_snapshot.get("actor_definition_id", "")) == "gojo_satoru":
			action_cast_event_found = true
	if not action_cast_event_found:
		return harness.fail_result("event log snapshot should expose derived actor_public_id and actor_definition_id")
	if not public_value_change_shape_checked:
		return harness.fail_result("event log snapshot should expose public-safe value_change entity identifiers")
	var empty_delta: Dictionary = manager.get_event_log_snapshot(session_id, int(delta_snapshot.get("total_size", 0)))
	if not empty_delta.get("events", []).is_empty():
		return harness.fail_result("event log snapshot tail query should return empty delta")
	manager.close_session(session_id)
	return harness.pass_result()
