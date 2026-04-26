extends "res://tests/support/gdunit_suite_bridge.gd"

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class SpyBattleResultService:
	extends "res://src/battle_core/turn/battle_result_service.gd"

	var reported_messages: Array[String] = []

	func _report_invalid_termination(message: String) -> void:
		reported_messages.append(message)


func test_terminate_invalid_battle_reports_error() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 501)
	core.service("battle_logger").reset()

	var spy_service = SpyBattleResultService.new()
	spy_service.id_factory = core.service("id_factory")
	spy_service.battle_logger = core.service("battle_logger")
	spy_service.log_event_builder = core.service("log_event_builder")
	spy_service.terminate_invalid_battle(battle_state, ErrorCodesScript.INVALID_COMMAND_PAYLOAD)

	if spy_service.reported_messages.size() != 1:
		fail("terminate_invalid_battle should report exactly one error message")
		return
	if spy_service.reported_messages[0].find(ErrorCodesScript.INVALID_COMMAND_PAYLOAD) == -1:
		fail("terminate_invalid_battle report should include invalid code")
		return
	if not battle_state.battle_result.finished or battle_state.battle_result.result_type != "no_winner":
		fail("terminate_invalid_battle result semantics changed")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		fail("terminate_invalid_battle should preserve invalid_code as reason")
		return
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
			return
	fail("terminate_invalid_battle should keep system:invalid_battle log semantics")

func test_hard_terminate_invalid_state_reports_error() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 502)
	core.service("battle_logger").reset()

	var spy_service = SpyBattleResultService.new()
	spy_service.id_factory = core.service("id_factory")
	spy_service.battle_logger = core.service("battle_logger")
	spy_service.log_event_builder = core.service("log_event_builder")
	spy_service.hard_terminate_invalid_state(battle_state, ErrorCodesScript.INVALID_STATE_CORRUPTION, "turn_loop_controller")

	if spy_service.reported_messages.size() != 1:
		fail("hard_terminate_invalid_state should report exactly one error message")
		return
	if spy_service.reported_messages[0].find(ErrorCodesScript.INVALID_STATE_CORRUPTION) == -1:
		fail("hard_terminate_invalid_state report should include invalid code")
		return
	if spy_service.reported_messages[0].find("turn_loop_controller") == -1:
		fail("hard_terminate_invalid_state report should include missing_dependency")
		return
	if not battle_state.battle_result.finished or battle_state.battle_result.result_type != "no_winner":
		fail("hard_terminate_invalid_state result semantics changed")
		return
	if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("hard_terminate_invalid_state should preserve invalid_code as reason")
		return
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_STATE_CORRUPTION:
			return
	fail("hard_terminate_invalid_state should keep system:invalid_battle log semantics")

