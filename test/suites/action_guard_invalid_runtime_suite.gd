extends "res://tests/support/gdunit_suite_bridge.gd"

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const RuleModInstanceScript := preload("res://src/battle_core/runtime/rule_mod_instance.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")


func test_invalid_state_corruption_guard() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 120)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	p1_active.current_hp = p1_active.max_hp + 1
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		fail("state corruption should fail-fast")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("expected invalid_state_corruption, got %s" % str(battle_state.battle_result.reason))
		return

func test_missing_active_slot_with_available_unit_guard() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 1201)
	battle_state.get_side("P1").clear_active_unit()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		fail("missing active slot with living units should fail-fast")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("missing active slot should map to invalid_state_corruption")
		return

func test_missing_chain_context_hard_fail() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 222)
	battle_state.clear_chain_context_stack()

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		fail("missing chain_context should fail-fast")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("missing chain_context should map to invalid_state_corruption")
		return
	for ev in core.service("battle_logger").event_log:
		if String(ev.event_chain_id) == "system:orphan":
			fail("system:orphan fallback should not exist")
			return
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
			return
	fail("missing invalid_battle log for missing chain_context")

func test_missing_core_dependency_hard_fail() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 223)
	core.service("turn_selection_resolver").legal_action_service = null

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		fail("missing core dependency should fail-fast")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("missing dependency should map to invalid_state_corruption")
		return
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
			return
	fail("missing invalid_battle log for dependency hard-fail")

func test_rule_mod_numeric_read_error_hard_fails_action() -> void:
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
	content_index.skills["sample_strike"].accuracy = 95
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 224)
	var target = battle_state.get_side("P2").get_active_unit()
	if target == null:
		fail("missing P2 active target")
		return
	var broken_rule_mod = RuleModInstanceScript.new()
	broken_rule_mod.instance_id = "test_broken_incoming_accuracy"
	broken_rule_mod.mod_kind = ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY
	broken_rule_mod.mod_op = "broken"
	broken_rule_mod.value = 0
	broken_rule_mod.duration_mode = ContentSchemaScript.DURATION_PERMANENT
	broken_rule_mod.owner_id = target.unit_instance_id
	target.rule_mod_instances.append(broken_rule_mod)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": "skill",
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
	])
	if not battle_state.battle_result.finished:
		fail("broken rule_mod numeric read should terminate battle")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
		fail("expected invalid_rule_mod_definition, got %s" % str(battle_state.battle_result.reason))
		return

