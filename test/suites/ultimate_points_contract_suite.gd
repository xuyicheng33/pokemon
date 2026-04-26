extends "res://tests/support/gdunit_suite_bridge.gd"

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const UltimateFieldTestHelperScript := preload("res://tests/support/ultimate_field_test_helper.gd")

var _helper = UltimateFieldTestHelperScript.new()


func test_ultimate_points_regular_skill_gain_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sample_state(_harness, 2201)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var initial_snapshot = core.service("public_snapshot_builder").build_public_snapshot(battle_state, content_index)
	var p1_snapshot = _helper.find_side_snapshot(initial_snapshot, "P1")
	if int(p1_snapshot.get("active_ultimate_points", -1)) != 0 \
	or int(p1_snapshot.get("active_ultimate_points_cap", -1)) != 3 \
	or int(p1_snapshot.get("active_ultimate_points_required", -1)) != 3:
		fail("公开快照必须暴露 Gojo 当前奥义点、上限与需求")
		return
	content_index.skills["gojo_ao"].accuracy = 0
	core.service("battle_logger").reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
		_helper.build_wait_command(core, 1, "P2", "P2-A")
	)
	if gojo_unit.ultimate_points != 1:
		fail("常规技能开始施放后即使 miss 也应获得 1 点奥义点")
		return
	if not _helper.has_ultimate_point_delta(core.service("battle_logger").event_log, 1, 1):
		fail("常规技能加点应写出独立 ultimate_points 资源变化日志")
		return
	gojo_unit.ultimate_points = 2
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_skill_command(core, 2, "P1", "P1-A", "gojo_aka"),
		_helper.build_wait_command(core, 2, "P2", "P2-A"),
	])
	if gojo_unit.ultimate_points != 3:
		fail("奥义点应按角色上限封顶")
		return
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_skill_command(core, 3, "P1", "P1-A", "gojo_aka"),
		_helper.build_wait_command(core, 3, "P2", "P2-A"),
	])
	if gojo_unit.ultimate_points != 3:
		fail("已满奥义点再次施放常规技能时不应溢出")
		return
	if _helper.has_ultimate_point_delta(core.service("battle_logger").event_log, 0, 3):
		fail("点数已满时不应再写出零变化 ultimate_points 日志")
		return

func test_ultimate_points_non_regular_switch_preserve_contract() -> void:
	var state_payload = _helper.build_gojo_vs_sample_state(_harness, 2202)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	gojo_unit.ultimate_points = 2
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_wait_command(core, 1, "P1", "P1-A"),
		_helper.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if gojo_unit.ultimate_points != 2:
		fail("wait 不应改变奥义点")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_switch_command(core, 2, "P1", "P1-A", "P1-B"),
		_helper.build_wait_command(core, 2, "P2", "P2-A"),
	])
	if gojo_unit.ultimate_points != 2:
		fail("换下后奥义点必须保留在原角色运行态上")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_switch_command(core, 3, "P1", "P1-B", "P1-A"),
		_helper.build_wait_command(core, 3, "P2", "P2-A"),
	])
	var reentered_gojo = battle_state.get_side("P1").get_active_unit()
	if reentered_gojo == null or reentered_gojo.definition_id != "gojo_satoru" or reentered_gojo.ultimate_points != 2:
		fail("换回后角色应带回原先保留的奥义点")
		return

func test_ultimate_points_ultimate_legality_and_reset_contract() -> void:
	var blocked_payload = _helper.build_gojo_vs_sample_state(_harness, 2203)
	if blocked_payload.has("error"):
		fail(str(blocked_payload["error"]))
		return
	var blocked_core = blocked_payload["core"]
	var blocked_content = blocked_payload["content_index"]
	var blocked_state = blocked_payload["battle_state"]
	var blocked_gojo = blocked_state.get_side("P1").get_active_unit()
	blocked_gojo.current_mp = blocked_gojo.max_mp
	var blocked_actions = blocked_core.service("legal_action_service").get_legal_actions(blocked_state, "P1", blocked_content)
	if blocked_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
		fail("奥义点不足时不应把奥义列为合法动作")
		return
	blocked_core.service("turn_loop_controller").run_turn(blocked_state, blocked_content, [
		_helper.build_ultimate_command(blocked_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(blocked_core, 1, "P2", "P2-A"),
	])
	if not blocked_state.battle_result.finished or blocked_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		fail("点数不足时手动提交奥义必须在选指阶段 fail-fast")
		return

	var ready_payload = _helper.build_gojo_vs_sample_state(_harness, 2204)
	if ready_payload.has("error"):
		fail(str(ready_payload["error"]))
		return
	var core = ready_payload["core"]
	var content_index = ready_payload["content_index"]
	var battle_state = ready_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	var ready_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if not ready_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
		fail("MP 与奥义点都满足时奥义必须合法")
		return
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_helper.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if gojo_unit.ultimate_points != 0:
		fail("奥义开始施放时必须清空奥义点")
		return
	if not _helper.has_ultimate_point_delta(core.service("battle_logger").event_log, -3, 0):
		fail("奥义清空点数必须写入资源变化日志")
		return
	var post_snapshot = core.service("public_snapshot_builder").build_public_snapshot(battle_state, content_index)
	if int(_helper.find_side_snapshot(post_snapshot, "P1").get("active_ultimate_points", -1)) != 0:
		fail("公开快照必须同步奥义释放后的清零状态")
		return

