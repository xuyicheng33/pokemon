extends RefCounted
class_name SelectionTimeoutAndWaitSuite

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("timeout_wait_path", failures, Callable(self, "_test_timeout_wait_path").bind(harness))
	runner.run_test("resource_forced_default_path", failures, Callable(self, "_test_resource_forced_default_path").bind(harness))
	runner.run_test("wait_allowed_non_mp_blocked_path", failures, Callable(self, "_test_wait_allowed_non_mp_blocked_path").bind(harness))
	runner.run_test("manual_wait_no_damage_path", failures, Callable(self, "_test_manual_wait_no_damage_path").bind(harness))

func _test_timeout_wait_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var replay_input = preload("res://src/battle_core/contracts/replay_input.gd").new()
	replay_input.battle_seed = 21
	replay_input.content_snapshot_paths = snapshot_paths_payload.get("paths", PackedStringArray())
	replay_input.battle_setup = harness.build_sample_setup(sample_factory)
	replay_input.command_stream = [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.SKILL, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sample_strike"}),
	]
	var replay_output = core.service("replay_runner").run_replay(replay_input)
	if replay_output == null:
		return harness.fail_result("replay output is null")
	for log_event in replay_output.event_log:
		if log_event.command_type == CommandTypesScript.WAIT and log_event.command_source == "timeout_auto" and log_event.event_type == EventTypesScript.ACTION_CAST:
			return harness.pass_result()
	return harness.fail_result("timeout wait cast event missing")

func _test_resource_forced_default_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray())):
		return harness.fail_result("content snapshot load failed: %s" % content_index.last_error_message)
	core.service("rng_service").reset(33)
	var battle_state = BattleStateScript.new()
	core.service("id_factory").reset()
	battle_state.battle_id = core.service("id_factory").next_id("battle")
	battle_state.seed = 33
	battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
	core.service("battle_initializer").initialize_battle(battle_state, content_index, harness.build_sample_setup(sample_factory))
	var p1 = battle_state.get_side("P1")
	if p1 == null:
		return harness.fail_result("side P1 missing after initialize")
	var p1_active = p1.get_active_unit()
	if p1_active == null:
		return harness.fail_result("P1 active unit missing after initialize")
	p1_active.current_mp = 0
	p1_active.regen_per_turn = 0
	for bench_unit_id in p1.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	var p2 = battle_state.get_side("P2")
	if p2 == null:
		return harness.fail_result("side P2 missing after initialize")
	var p2_active = p2.get_active_unit()
	if p2_active == null:
		return harness.fail_result("P2 active unit missing after initialize")
	p2_active.current_mp = 0
	p2_active.regen_per_turn = 0
	for bench_unit_id in p2.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	for log_event in core.service("battle_logger").event_log:
		if log_event.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT and log_event.event_type == EventTypesScript.ACTION_CAST:
			return harness.pass_result()
	return harness.fail_result("resource_forced_default cast event missing")

func _test_wait_allowed_non_mp_blocked_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var snapshot_paths_payload: Dictionary = harness.build_content_snapshot_paths(sample_factory)
	if snapshot_paths_payload.has("error"):
		return harness.fail_result(str(snapshot_paths_payload.get("error", "content snapshot path build failed")))
	var content_index = BattleContentIndexScript.new()
	if not content_index.load_snapshot(snapshot_paths_payload.get("paths", PackedStringArray())):
		return harness.fail_result("content snapshot load failed: %s" % content_index.last_error_message)
	core.service("rng_service").reset(34)
	var battle_state = BattleStateScript.new()
	core.service("id_factory").reset()
	battle_state.battle_id = core.service("id_factory").next_id("battle")
	battle_state.seed = 34
	battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
	core.service("battle_initializer").initialize_battle(battle_state, content_index, harness.build_sample_setup(sample_factory))
	var p1 = battle_state.get_side("P1")
	if p1 == null:
		return harness.fail_result("side P1 missing after initialize")
	var p1_active = p1.get_active_unit()
	if p1_active == null:
		return harness.fail_result("P1 active unit missing after initialize")
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
		return harness.fail_result("failed to create legality deny rule_mod")
	var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if not legal_action_set.wait_allowed:
		return harness.fail_result("wait should be allowed when non-mp blocked option exists")
	if not legal_action_set.forced_command_type.is_empty():
		return harness.fail_result("forced_command_type must be empty when wait is allowed")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	for log_event in core.service("battle_logger").event_log:
		if log_event.command_type == CommandTypesScript.WAIT and log_event.command_source == "timeout_auto" and log_event.event_type == EventTypesScript.ACTION_CAST:
			return harness.pass_result()
	return harness.fail_result("timeout_auto should resolve to wait when non-mp block exists")

func _test_manual_wait_no_damage_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 35)
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
			return harness.fail_result("wait should not deal damage or recoil")
		if log_event.command_type == CommandTypesScript.WAIT and log_event.event_type == EventTypesScript.ACTION_HIT:
			return harness.fail_result("wait should not enter hit/miss flow")
	if not has_wait_cast:
		return harness.fail_result("manual wait cast event missing")
	return harness.pass_result()
