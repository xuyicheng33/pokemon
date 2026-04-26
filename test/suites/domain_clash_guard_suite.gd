extends "res://tests/support/gdunit_suite_bridge.gd"

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EffectEventScript := preload("res://src/battle_core/contracts/effect_event.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const UltimateFieldTestHelperScript := preload("res://tests/support/ultimate_field_test_helper.gd")

var _helper = UltimateFieldTestHelperScript.new()


func test_same_side_active_domain_recast_block_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sample_state(_harness, 2208)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 1, "P2", "P2-A")
	)
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		fail("Gojo 首次开领域后应成功立场")
		return
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	var legal_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if legal_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
		fail("己方领域在场时，己方不应再次施放领域技能")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_ultimate_command(core, 2, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 2, "P2", "P2-A"),
	])
	if not battle_state.battle_result.finished or battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		fail("领域重开非法时，手动提交领域技能应在选指阶段 fail-fast")
		return

func test_active_domain_missing_creator_fails_fast_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sukuna_state(_harness, 2213)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var invalid_field = FieldStateScript.new()
	invalid_field.field_def_id = "gojo_unlimited_void_field"
	invalid_field.instance_id = "test_invalid_domain_field"
	invalid_field.creator = "missing_creator"
	invalid_field.remaining_turns = 2
	battle_state.field_state = invalid_field
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_wait_command(core, 1, "P1", "P1-A"),
		_helper.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if not battle_state.battle_result.finished or battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("active domain 缺失 creator 时必须 fail-fast 为 invalid_state_corruption")
		return

func test_active_domain_missing_creator_legal_actions_fail_fast_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sukuna_state(_harness, 22132)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var invalid_field = FieldStateScript.new()
	invalid_field.field_def_id = "gojo_unlimited_void_field"
	invalid_field.instance_id = "test_invalid_domain_field_for_legal_actions"
	invalid_field.creator = ""
	invalid_field.remaining_turns = 2
	battle_state.field_state = invalid_field
	var legal_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if legal_actions != null:
		fail("legal_action_service should fail-fast instead of treating broken domain state as no active domain")
		return
	if core.service("legal_action_service").last_error_code != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("broken active domain state should surface invalid_state_corruption in legal_action_service")
		return

func test_active_domain_inactive_creator_fails_fast_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sukuna_state(_harness, 22133)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var creator_unit = battle_state.get_side("P1").get_active_unit()
	if creator_unit == null:
		fail("missing creator unit for inactive creator guard contract")
		return
	var invalid_field = FieldStateScript.new()
	invalid_field.field_def_id = "gojo_unlimited_void_field"
	invalid_field.instance_id = "test_invalid_domain_field_inactive_creator"
	invalid_field.creator = creator_unit.unit_instance_id
	invalid_field.remaining_turns = 2
	battle_state.field_state = invalid_field
	creator_unit.current_hp = 0
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_wait_command(core, 1, "P1", "P1-A"),
		_helper.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if not battle_state.battle_result.finished or battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("active domain with inactive creator should fail-fast as invalid_state_corruption")
		return

func test_active_field_missing_creator_local_guard_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sample_state(_harness, 22131)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var invalid_field = FieldStateScript.new()
	invalid_field.field_def_id = "sample_focus_field"
	invalid_field.instance_id = "test_invalid_local_field"
	invalid_field.creator = ""
	invalid_field.remaining_turns = 2
	battle_state.field_state = invalid_field
	var invalid_code = core.service("field_service").break_field_if_creator_inactive(
		battle_state,
		content_index,
		battle_state.current_chain_context()
	)
	if invalid_code != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("field_service local path should fail-fast when creator is empty")
		return

func test_same_side_domain_recast_main_path_fails_fast_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sample_state(_harness, 2214)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 1, "P2", "P2-A")
	)
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		fail("前置条件失败：Gojo 首次开领域后应成功立场")
		return
	var before_field_instance_id := String(battle_state.field_state.instance_id)
	var before_field_creator := String(battle_state.field_state.creator)
	var apply_effect = content_index.effects.get("gojo_apply_domain_field", null)
	if apply_effect == null or apply_effect.payloads.is_empty():
		fail("前置条件失败：缺少 gojo_apply_domain_field 资源")
		return
	var effect_event = EffectEventScript.new()
	effect_event.event_id = "test_same_side_domain_recast_main_path"
	effect_event.trigger_name = "on_hit"
	effect_event.priority = 5
	effect_event.source_instance_id = "test_same_side_domain_recast_action"
	effect_event.source_kind_order = 2
	effect_event.source_order_speed_snapshot = gojo_unit.base_speed
	effect_event.effect_definition_id = "gojo_apply_domain_field"
	effect_event.owner_id = gojo_unit.unit_instance_id
	core.service("battle_logger").reset()
	var invalid_code = core.service("field_apply_service").apply_field(
		apply_effect,
		apply_effect.payloads[0],
		effect_event,
		battle_state,
		content_index
	)
	if invalid_code != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		fail("同侧领域重开若进入 field clash 主路径必须 fail-fast 为 invalid_state_corruption")
		return
	if battle_state.field_state == null or String(battle_state.field_state.instance_id) != before_field_instance_id or String(battle_state.field_state.creator) != before_field_creator:
		fail("同侧领域重开 fail-fast 后不应刷新 active field 状态")
		return
	if _helper.find_field_clash_event(core.service("battle_logger").event_log) != null:
		fail("同侧领域重开 fail-fast 后不应写出领域对拼日志")
		return

