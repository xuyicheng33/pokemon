extends "res://tests/support/gdunit_suite_bridge.gd"

const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ActionGuardStateIntegrityTestSupportScript := preload("res://tests/support/action_guard_state_integrity_test_support.gd")

var _support = ActionGuardStateIntegrityTestSupportScript.new()


func test_effect_expire_invalid_terminates_turn_immediately() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 1202)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	_support.register_ambiguous_remove_content(content_index, "test_effect_expire_invalid", "on_expire")
	core.service("effect_instance_service").create_instance(content_index.effects["test_effect_expire_invalid_marker"], target.unit_instance_id, battle_state, "test_marker_source", 1, target.base_speed)
	core.service("effect_instance_service").create_instance(content_index.effects["test_effect_expire_invalid_marker"], target.unit_instance_id, battle_state, "test_marker_source", 1, target.base_speed)
	core.service("effect_instance_service").create_instance(content_index.effects["test_effect_expire_invalid_parent"], actor.unit_instance_id, battle_state, "test_parent_source", 1, actor.base_speed)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		fail("invalid effect expire path should terminate battle immediately")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_EFFECT_REMOVE_AMBIGUOUS:
		fail("invalid effect expire should preserve remove_effect ambiguity code")
		return
	if battle_state.turn_index != 1:
		fail("effect expire invalid path must not advance turn index")
		return
	if core.service("battle_logger").event_log.is_empty() or core.service("battle_logger").event_log[-1].event_type != EventTypesScript.SYSTEM_INVALID_BATTLE:
		fail("invalid effect expire should stop with system:invalid_battle as the last event")
		return
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.ACTION_CAST:
			fail("invalid effect expire at turn_start must stop before action selection/execution")
			return

func test_field_expire_invalid_terminates_turn_immediately() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 1203)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	_support.register_ambiguous_remove_content(content_index, "test_field_expire_invalid", "field_expire")
	var invalid_field = FieldStateScript.new()
	invalid_field.field_def_id = "test_field_expire_invalid_field"
	invalid_field.instance_id = "test_field_expire_invalid_instance"
	invalid_field.creator = actor.unit_instance_id
	invalid_field.remaining_turns = 1
	battle_state.field_state = invalid_field
	core.service("effect_instance_service").create_instance(content_index.effects["test_field_expire_invalid_marker"], target.unit_instance_id, battle_state, "test_field_marker_source", 1, target.base_speed)
	core.service("effect_instance_service").create_instance(content_index.effects["test_field_expire_invalid_marker"], target.unit_instance_id, battle_state, "test_field_marker_source", 1, target.base_speed)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		fail("invalid field expire path should terminate battle immediately")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_EFFECT_REMOVE_AMBIGUOUS:
		fail("invalid field expire should preserve remove_effect ambiguity code")
		return
	if battle_state.turn_index != 1:
		fail("invalid field expire path must not advance turn index")
		return
	if core.service("battle_logger").event_log.is_empty() or core.service("battle_logger").event_log[-1].event_type != EventTypesScript.SYSTEM_INVALID_BATTLE:
		fail("invalid field expire should stop with system:invalid_battle as the last event")
		return
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
			fail("invalid field expire should stop before writing EFFECT_FIELD_EXPIRE")
			return

