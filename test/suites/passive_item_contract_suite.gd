extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

var _helper = ManagerContractTestHelperScript.new()


func test_passive_item_sample_snapshot_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var unit_definition = content_index.units.get("sample_pyron_charm", null)
	if unit_definition == null:
		fail("missing sample_pyron_charm unit definition")
		return
	if String(unit_definition.passive_item_id) != "sample_attack_charm":
		fail("sample_pyron_charm should point to sample_attack_charm")
		return
	var passive_item = content_index.passive_items.get("sample_attack_charm", null)
	if passive_item == null:
		fail("missing sample_attack_charm passive item definition")
		return
	if passive_item.effect_ids != PackedStringArray(["sample_attack_charm_bonus"]):
		fail("sample_attack_charm should apply sample_attack_charm_bonus on enter")
		return
	var effect_definition = content_index.effects.get("sample_attack_charm_bonus", null)
	if effect_definition == null:
		fail("missing sample_attack_charm_bonus effect definition")
		return
	if effect_definition.payloads.size() != 1 or not effect_definition.payloads[0] is RuleModPayloadScript:
		fail("sample_attack_charm_bonus should contain a single rule_mod payload")
		return
	var payload = effect_definition.payloads[0]
	if String(payload.mod_kind) != "final_mod" or String(payload.mod_op) != "mul" or float(payload.value) != 1.5:
		fail("sample_attack_charm_bonus rule_mod payload mismatch")
		return

func test_passive_item_runtime_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var baseline_content_index = _harness.build_loaded_content_index(sample_factory)
	var baseline_battle_state = _harness.build_initialized_battle(
		core,
		baseline_content_index,
		sample_factory,
		1901,
		_harness.build_sample_setup(sample_factory)
	)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(baseline_battle_state, baseline_content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var baseline_damage: int = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	var baseline_target = baseline_battle_state.get_side("P2").get_active_unit()
	if baseline_target == null:
		fail("missing baseline target")
		return

	var item_content_index = _harness.build_loaded_content_index(sample_factory)
	var item_battle_state = _harness.build_initialized_battle(
		core,
		item_content_index,
		sample_factory,
		1901,
		_harness.build_setup_by_matchup_id(sample_factory, "passive_item_vs_sample")
	)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(item_battle_state, item_content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var item_damage: int = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	var item_target = item_battle_state.get_side("P2").get_active_unit()
	if item_target == null:
		fail("missing passive item target")
		return
	if baseline_damage <= 0 or item_damage <= baseline_damage:
		fail("sample_attack_charm should increase first-turn sample_strike damage")
		return
	if item_target.current_hp >= baseline_target.current_hp:
		fail("passive item runtime path should leave the target with less hp than baseline")
		return

func test_passive_item_manager_smoke_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var baseline_result = _run_manager_damage_case(_harness, manager, sample_factory, _harness.build_sample_setup(sample_factory), 1901)
	if baseline_result.has("error"):
		fail(str(baseline_result["error"]))
		return
	var item_result = _run_manager_damage_case(_harness, manager, sample_factory, _harness.build_setup_by_matchup_id(sample_factory, "passive_item_vs_sample"), 1901)
	if item_result.has("error"):
		fail(str(item_result["error"]))
		return
	if int(item_result.get("damage", 0)) <= int(baseline_result.get("damage", 0)):
		fail("passive item manager smoke should increase damage over the baseline sample unit")
		return
	var prebattle_public_teams: Array = item_result.get("prebattle_public_teams", [])
	var prebattle_unit = _find_prebattle_unit(prebattle_public_teams, "P1", "P1-A")
	if prebattle_unit.is_empty():
		fail("passive item manager smoke should expose prebattle P1-A")
		return
	if String(prebattle_unit.get("passive_item_id", "")) != "sample_attack_charm":
		fail("passive item manager smoke should expose passive_item_id in prebattle_public_teams")
		return

func test_passive_item_replay_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var baseline_input = _build_single_strike_replay_input(_harness, manager, sample_factory, _harness.build_sample_setup(sample_factory), 1901)
	if baseline_input == null:
		fail("failed to build baseline replay input")
		return
	var item_input = _build_single_strike_replay_input(_harness, manager, sample_factory, _harness.build_setup_by_matchup_id(sample_factory, "passive_item_vs_sample"), 1901)
	if item_input == null:
		fail("failed to build passive item replay input")
		return
	var baseline_unwrap = _helper.unwrap_ok(manager.run_replay(baseline_input), "run_replay_baseline")
	if not bool(baseline_unwrap.get("ok", false)):
		fail(str(baseline_unwrap.get("error", "baseline replay failed")))
		return
	var item_unwrap = _helper.unwrap_ok(manager.run_replay(item_input), "run_replay_item")
	if not bool(item_unwrap.get("ok", false)):
		fail(str(item_unwrap.get("error", "passive item replay failed")))
		return
	var baseline_data: Dictionary = baseline_unwrap.get("data", {})
	var item_data: Dictionary = item_unwrap.get("data", {})
	var baseline_snapshot: Dictionary = baseline_data.get("public_snapshot", {})
	var item_snapshot: Dictionary = item_data.get("public_snapshot", {})
	var baseline_target = _find_team_unit(baseline_snapshot, "P2", "P2-A")
	var item_target = _find_team_unit(item_snapshot, "P2", "P2-A")
	if baseline_target.is_empty() or item_target.is_empty():
		fail("passive item replay contract missing target snapshot")
		return
	if int(item_target.get("current_hp", -1)) >= int(baseline_target.get("current_hp", -1)):
		fail("passive item replay should preserve higher damage than the baseline replay")
		return
	var replay_output = item_data.get("replay_output", null)
	if replay_output == null or not replay_output.succeeded:
		fail("passive item replay should succeed")
		return
	var prebattle_unit = _find_prebattle_unit(item_snapshot.get("prebattle_public_teams", []), "P1", "P1-A")
	if prebattle_unit.is_empty() or String(prebattle_unit.get("passive_item_id", "")) != "sample_attack_charm":
		fail("passive item replay should keep passive_item_id visible in public snapshot")
		return


func _run_manager_damage_case(harness, manager, sample_factory, battle_setup, battle_seed: int) -> Dictionary:
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return {"error": snapshot_paths_payload.get("error", "content snapshot path build failed")}
	var init_unwrap = _helper.unwrap_ok(manager.create_session({
		"battle_seed": battle_seed,
		"content_snapshot_paths": snapshot_paths_payload.get("paths", PackedStringArray()),
		"battle_setup": battle_setup,
	}), "create_session")
	if not bool(init_unwrap.get("ok", false)):
		return {"error": init_unwrap.get("error", "create_session failed")}
	var init_data: Dictionary = init_unwrap.get("data", {})
	var session_id := String(init_data.get("session_id", ""))
	var run_turn_unwrap = _helper.unwrap_ok(manager.run_turn(session_id, [
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
		manager.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	]), "run_turn")
	if not bool(run_turn_unwrap.get("ok", false)):
		return {"error": run_turn_unwrap.get("error", "run_turn failed")}
	var public_snapshot_unwrap = _helper.unwrap_ok(manager.get_public_snapshot(session_id), "get_public_snapshot")
	if not bool(public_snapshot_unwrap.get("ok", false)):
		return {"error": public_snapshot_unwrap.get("error", "get_public_snapshot failed")}
	var event_log_unwrap = _helper.unwrap_ok(manager.get_event_log_snapshot(session_id), "get_event_log_snapshot")
	if not bool(event_log_unwrap.get("ok", false)):
		return {"error": event_log_unwrap.get("error", "get_event_log_snapshot failed")}
	var close_unwrap = _helper.unwrap_ok(manager.close_session(session_id), "close_session")
	if not bool(close_unwrap.get("ok", false)):
		return {"error": close_unwrap.get("error", "close_session failed")}
	return {
		"damage": _extract_public_damage_delta(event_log_unwrap.get("data", {}).get("events", []), "P2-A"),
		"public_snapshot": public_snapshot_unwrap.get("data", {}),
		"prebattle_public_teams": init_data.get("prebattle_public_teams", []),
	}

func _build_single_strike_replay_input(harness, command_port, sample_factory, battle_setup, battle_seed: int):
	if command_port == null or not command_port.has_method("build_command"):
		return null
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return null
	var replay_input = ReplayInputScript.new()
	replay_input.battle_seed = battle_seed
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = battle_setup
	var p1_command = _helper.unwrap_ok(command_port.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_public_id": "P1-A",
		"skill_id": "sample_strike",
	}), "build_command_p1")
	if not bool(p1_command.get("ok", false)):
		return null
	var p2_command = _helper.unwrap_ok(command_port.build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.WAIT,
		"command_source": "manual",
		"side_id": "P2",
		"actor_public_id": "P2-A",
	}), "build_command_p2")
	if not bool(p2_command.get("ok", false)):
		return null
	replay_input.command_stream = [p1_command.get("data", null), p2_command.get("data", null)]
	return replay_input

func _extract_public_damage_delta(events: Array, target_public_id: String) -> int:
	for event_snapshot in events:
		if String(event_snapshot.get("event_type", "")) != "effect:damage":
			continue
		for value_change in event_snapshot.get("value_changes", []):
			if String(value_change.get("entity_public_id", "")) == target_public_id:
				return abs(int(value_change.get("delta", 0)))
	return 0

func _find_prebattle_unit(prebattle_public_teams: Array, side_id: String, public_id: String) -> Dictionary:
	for side_snapshot in prebattle_public_teams:
		if String(side_snapshot.get("side_id", "")) != side_id:
			continue
		for unit_snapshot in side_snapshot.get("units", []):
			if String(unit_snapshot.get("public_id", "")) == public_id:
				return unit_snapshot
	return {}

func _find_team_unit(public_snapshot: Dictionary, side_id: String, public_id: String) -> Dictionary:
	for side_snapshot in public_snapshot.get("sides", []):
		if String(side_snapshot.get("side_id", "")) != side_id:
			continue
		for unit_snapshot in side_snapshot.get("team_units", []):
			if String(unit_snapshot.get("public_id", "")) == public_id:
				return unit_snapshot
	return {}
