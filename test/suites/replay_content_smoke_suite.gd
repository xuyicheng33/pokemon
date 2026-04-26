extends "res://tests/support/gdunit_suite_bridge.gd"

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")


func test_sukuna_content_pack_smoke() -> void:
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
	var battle_setup = _harness.build_sample_setup(sample_factory)
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
		fail("missing P1 active unit for sukuna smoke")
		return
	p1_active.current_mp = p1_active.max_mp
	p1_active.ultimate_points = p1_active.ultimate_points_cap
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.ULTIMATE, "command_source": "manual", "side_id": "P1", "actor_public_id": "P1-A", "skill_id": "sukuna_fukuma_mizushi"}),
		core.service("command_builder").build_command({"turn_index": 1, "command_type": CommandTypesScript.WAIT, "command_source": "manual", "side_id": "P2", "actor_public_id": "P2-A"}),
	])
	if battle_state.battle_result.finished:
		fail("sukuna smoke battle should continue")
		return
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sukuna_malevolent_shrine_field":
		fail("sukuna ultimate should apply malevolent shrine field")
		return
	if battle_state.field_state.remaining_turns != 2:
		fail("malevolent shrine should count current turn as turn 1 and tick to 2 remaining")
		return
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.EFFECT_APPLY_FIELD and String(log_event.payload_summary).find("sukuna_malevolent_shrine_field") != -1:
			return
	fail("malevolent shrine apply event missing")

func test_field_expire_path() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var replay_input_result: Dictionary = sample_factory.build_demo_replay_input_for_profile_result(core.service("command_builder"), "legacy")
	if not bool(replay_input_result.get("ok", false)):
		fail("legacy replay input build failed: %s" % String(replay_input_result.get("error_message", "unknown error")))
		return
	var replay_output = core.service("replay_runner").run_replay(replay_input_result.get("data", null))
	if replay_output == null:
		fail("replay output is null")
		return
	if replay_output.final_battle_state.field_state != null:
		fail("field_state should expire after turn 2")
		return
	for log_event in replay_output.event_log:
		if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
			return
	fail("field expire event missing")

