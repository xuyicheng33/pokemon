extends RefCounted
class_name ReplayContentSmokeSuite

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("sukuna_content_pack_smoke", failures, Callable(self, "_test_sukuna_content_pack_smoke").bind(harness))
	runner.run_test("field_expire_path", failures, Callable(self, "_test_field_expire_path").bind(harness))

func _test_sukuna_content_pack_smoke(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_setup = harness.build_sample_setup(sample_factory)
	battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_tidekit"])
	battle_setup.sides[0].starting_index = 0
	battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
	battle_setup.sides[1].starting_index = 0
	core.service("rng_service").reset(36)
	core.service("id_factory").reset()
	var battle_state = BattleStateScript.new()
	battle_state.battle_id = core.service("id_factory").next_id("battle")
	battle_state.seed = 36
	battle_state.rng_stream_index = core.service("rng_service").get_stream_index()
	core.service("battle_initializer").initialize_battle(battle_state, content_index, battle_setup)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	if p1_active == null:
		return harness.fail_result("missing P1 active unit for sukuna smoke")
	p1_active.current_mp = p1_active.max_mp
	p1_active.ultimate_points = p1_active.ultimate_points_cap
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.ULTIMATE, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sukuna_fukuma_mizushi"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.WAIT, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A"}),
	])
	if battle_state.battle_result.finished:
		return harness.fail_result("sukuna smoke battle should continue")
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sukuna_malevolent_shrine_field":
		return harness.fail_result("sukuna ultimate should apply malevolent shrine field")
	if battle_state.field_state.remaining_turns != 2:
		return harness.fail_result("malevolent shrine should count current turn as turn 1 and tick to 2 remaining")
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.EFFECT_APPLY_FIELD and String(log_event.payload_summary).find("sukuna_malevolent_shrine_field") != -1:
			return harness.pass_result()
	return harness.fail_result("malevolent shrine apply event missing")

func _test_field_expire_path(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var replay_output = core.service("replay_runner").run_replay(harness.build_demo_replay_input(sample_factory, core.service("command_builder")))
	if replay_output == null:
		return harness.fail_result("replay output is null")
	if replay_output.final_battle_state.field_state != null:
		return harness.fail_result("field_state should expire after turn 2")
	for log_event in replay_output.event_log:
		if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
			return harness.pass_result()
	return harness.fail_result("field expire event missing")
