extends "res://tests/support/gdunit_suite_bridge.gd"

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const PassiveFailFastTestSupportScript := preload("res://tests/support/passive_fail_fast_test_support.gd")

var _support = PassiveFailFastTestSupportScript.new()


func test_invalid_passive_skill_trigger_source_fails_fast() -> void:
	var payload = _build_invalid_passive_battle(_harness, "skill")
	if payload.has("error"):
		fail(str(payload["error"]))
		return
	var __legacy_result = _run_invalid_trigger_source_turn_and_assert(_harness, payload["core"], payload["content_index"], payload["battle_state"], "passive skill")
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

func test_invalid_passive_item_trigger_source_fails_fast() -> void:
	var payload = _build_invalid_passive_battle(_harness, "item")
	if payload.has("error"):
		fail(str(payload["error"]))
		return
	var __legacy_result = _run_invalid_trigger_source_turn_and_assert(_harness, payload["core"], payload["content_index"], payload["battle_state"], "passive item")
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

func test_invalid_field_trigger_source_fails_fast() -> void:
	var payload = _build_invalid_field_battle(_harness)
	if payload.has("error"):
		fail(str(payload["error"]))
		return
	var __legacy_result = _run_invalid_trigger_source_turn_and_assert(_harness, payload["core"], payload["content_index"], payload["battle_state"], "field")
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))


func _build_invalid_passive_battle(harness, passive_kind: String) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"error": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	if passive_kind == "skill":
		_support.register_invalid_passive_skill(content_index, "sample_pyron")
	else:
		_support.register_invalid_passive_item(content_index, "sample_pyron")
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1301 if passive_kind == "skill" else 1302)
	return {
		"core": core,
		"content_index": content_index,
		"battle_state": battle_state,
	}

func _build_invalid_field_battle(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"error": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1303)
	var actor = battle_state.get_side("P1").get_active_unit()
	if actor == null:
		return {"error": "missing active unit for invalid field battle"}
	var field_id := "test_invalid_field"
	_support.register_invalid_field(content_index, field_id)
	var field_state = FieldStateScript.new()
	field_state.field_def_id = field_id
	field_state.instance_id = "test_invalid_field_instance"
	field_state.creator = actor.unit_instance_id
	field_state.remaining_turns = 2
	field_state.source_instance_id = "test_invalid_field_source"
	field_state.source_order_speed_snapshot = actor.base_speed
	battle_state.field_state = field_state
	return {
		"core": core,
		"content_index": content_index,
		"battle_state": battle_state,
	}

func _run_invalid_trigger_source_turn_and_assert(harness, core, content_index, battle_state, label: String) -> Dictionary:
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("%s invalid trigger source should terminate battle immediately" % label)
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_EFFECT_DEFINITION:
		return harness.fail_result("%s invalid trigger source should preserve invalid_effect_definition" % label)
	if battle_state.turn_index != 1:
		return harness.fail_result("%s invalid trigger source must stop before advancing turn index" % label)
	if core.service("battle_logger").event_log.is_empty():
		return harness.fail_result("%s invalid trigger source should leave an invalid_battle log" % label)
	if core.service("battle_logger").event_log[-1].event_type != EventTypesScript.SYSTEM_INVALID_BATTLE:
		return harness.fail_result("%s invalid trigger source should stop with system:invalid_battle" % label)
	for log_event in core.service("battle_logger").event_log:
		if log_event.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and log_event.invalid_battle_code == ErrorCodesScript.INVALID_EFFECT_DEFINITION:
			return harness.pass_result()
		if log_event.event_type == EventTypesScript.ACTION_CAST:
			return harness.fail_result("%s invalid trigger source should fail before action execution" % label)
	return harness.fail_result("%s invalid trigger source missing invalid_battle log payload" % label)
