extends "res://tests/support/gdunit_suite_bridge.gd"

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")


func test_timeout_wait_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var replay_input = preload("res://src/battle_core/contracts/replay_input.gd").new()
	replay_input.battle_seed = 21
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = _harness.build_sample_setup(sample_factory)
	replay_input.command_stream = [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
	]
	var replay_output = core.service("replay_runner").run_replay(replay_input)
	if replay_output == null:
		fail("replay output is null")
		return
	for log_event in replay_output.event_log:
		if log_event.command_type == CommandTypesScript.WAIT and log_event.command_source == "timeout_auto" and log_event.event_type == EventTypesScript.ACTION_CAST:
			return
	fail("timeout wait cast event missing")

func test_resource_forced_default_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray())):
		fail("content snapshot load failed: %s" % content_index.last_error_message)
		return
	core.service("rng_service").reset(33)
	var battle_state = BattleStateScript.new()
	core.service("id_factory").reset()
	battle_state.battle_id = core.service("id_factory").next_id("battle")
	battle_state.seed = 33
	battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
	core.service("battle_initializer").initialize_battle(battle_state, content_index, _harness.build_sample_setup(sample_factory))
	var p1 = battle_state.get_side("P1")
	if p1 == null:
		fail("side P1 missing after initialize")
		return
	var p1_active = p1.get_active_unit()
	if p1_active == null:
		fail("P1 active unit missing after initialize")
		return
	p1_active.current_mp = 0
	p1_active.regen_per_turn = 0
	for bench_unit_id in p1.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	var p2 = battle_state.get_side("P2")
	if p2 == null:
		fail("side P2 missing after initialize")
		return
	var p2_active = p2.get_active_unit()
	if p2_active == null:
		fail("P2 active unit missing after initialize")
		return
	p2_active.current_mp = 0
	p2_active.regen_per_turn = 0
	for bench_unit_id in p2.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	for log_event in core.service("battle_logger").event_log:
		if log_event.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT and log_event.event_type == EventTypesScript.ACTION_CAST:
			return
	fail("resource_forced_default cast event missing")

func test_wait_allowed_non_mp_blocked_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var snapshot_paths_payload: Dictionary = _harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		fail(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
		return
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray())):
		fail("content snapshot load failed: %s" % content_index.last_error_message)
		return
	core.service("rng_service").reset(34)
	var battle_state = BattleStateScript.new()
	core.service("id_factory").reset()
	battle_state.battle_id = core.service("id_factory").next_id("battle")
	battle_state.seed = 34
	battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
	core.service("battle_initializer").initialize_battle(battle_state, content_index, _harness.build_sample_setup(sample_factory))
	var p1 = battle_state.get_side("P1")
	if p1 == null:
		fail("side P1 missing after initialize")
		return
	var p1_active = p1.get_active_unit()
	if p1_active == null:
		fail("P1 active unit missing after initialize")
		return
	p1_active.current_mp = 0
	p1_active.regen_per_turn = 0
	for bench_unit_id in p1.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	var deny_payload = RuleModPayloadScript.new()
	deny_payload.payload_type = "rule_mod"
	deny_payload.mod_kind = "action_legality"
	deny_payload.mod_op = "deny"
	deny_payload.value = "sample_strike"
	deny_payload.scope = "self"
	deny_payload.duration_mode = "turns"
	deny_payload.duration = 2
	deny_payload.decrement_on = "turn_start"
	deny_payload.stacking = "replace"
	deny_payload.priority = 10
	if core.service("rule_mod_service").create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_wait_non_mp_blocked", 0, p1_active.base_speed) == null:
		fail("failed to create legality deny rule_mod")
		return
	var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if not legal_action_set.wait_allowed:
		fail("wait should be allowed when non-mp blocked option exists")
		return
	if not legal_action_set.forced_command_type.is_empty():
		fail("forced_command_type must be empty when wait is allowed")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	for log_event in core.service("battle_logger").event_log:
		if log_event.command_type == CommandTypesScript.WAIT and log_event.command_source == "timeout_auto" and log_event.event_type == EventTypesScript.ACTION_CAST:
			return
	fail("timeout_auto should resolve to wait when non-mp block exists")

func test_manual_wait_no_damage_path() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 35)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.WAIT, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A", "skill_id": "sample_strike"}),
	])
	var has_wait_cast: bool = false
	for log_event in core.service("battle_logger").event_log:
		if log_event.command_type == CommandTypesScript.WAIT and log_event.event_type == EventTypesScript.ACTION_CAST:
			has_wait_cast = true
			continue
		if log_event.command_type == CommandTypesScript.WAIT and log_event.event_type == EventTypesScript.EFFECT_DAMAGE:
			fail("wait should not deal damage or recoil")
			return
		if log_event.command_type == CommandTypesScript.WAIT and log_event.event_type == EventTypesScript.ACTION_HIT:
			fail("wait should not enter hit/miss flow")
			return
	if not has_wait_cast:
		fail("manual wait cast event missing")
		return

