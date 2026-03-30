extends RefCounted
class_name DomainClashContractSuite

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EffectEventScript := preload("res://src/battle_core/contracts/effect_event.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const UltimateFieldTestHelperScript := preload("res://tests/support/ultimate_field_test_helper.gd")

var _helper = UltimateFieldTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("field_clash_high_mp_and_success_only_followup_contract", failures, Callable(self, "_test_field_clash_high_mp_and_success_only_followup_contract").bind(harness))
	runner.run_test("field_clash_tie_replay_contract", failures, Callable(self, "_test_field_clash_tie_replay_contract").bind(harness))
	runner.run_test("same_side_active_domain_recast_block_contract", failures, Callable(self, "_test_same_side_active_domain_recast_block_contract").bind(harness))
	runner.run_test("opponent_domain_cast_still_legal_contract", failures, Callable(self, "_test_opponent_domain_cast_still_legal_contract").bind(harness))
	runner.run_test("same_turn_dual_domain_not_cancelled_by_action_lock_contract", failures, Callable(self, "_test_same_turn_dual_domain_not_cancelled_by_action_lock_contract").bind(harness))
	runner.run_test("normal_field_cannot_replace_active_domain_contract", failures, Callable(self, "_test_normal_field_cannot_replace_active_domain_contract").bind(harness))
	runner.run_test("domain_replaces_normal_field_contract", failures, Callable(self, "_test_domain_replaces_normal_field_contract").bind(harness))
	runner.run_test("active_domain_missing_creator_fails_fast_contract", failures, Callable(self, "_test_active_domain_missing_creator_fails_fast_contract").bind(harness))
	runner.run_test("active_field_missing_creator_local_guard_contract", failures, Callable(self, "_test_active_field_missing_creator_local_guard_contract").bind(harness))
	runner.run_test("same_side_domain_recast_main_path_fails_fast_contract", failures, Callable(self, "_test_same_side_domain_recast_main_path_fails_fast_contract").bind(harness))

func _test_field_clash_high_mp_and_success_only_followup_contract(harness) -> Dictionary:
	var lose_payload = _helper.build_gojo_vs_sukuna_state(harness, 2205)
	if lose_payload.has("error"):
		return harness.fail_result(str(lose_payload["error"]))
	var lose_core = lose_payload["core"]
	var lose_content = lose_payload["content_index"]
	var lose_state = lose_payload["battle_state"]
	var lose_gojo = lose_state.get_side("P1").get_active_unit()
	var lose_sukuna = lose_state.get_side("P2").get_active_unit()
	lose_gojo.current_mp = 90
	lose_gojo.ultimate_points = lose_gojo.ultimate_points_cap
	lose_sukuna.current_mp = lose_sukuna.max_mp
	lose_sukuna.ultimate_points = lose_sukuna.ultimate_points_cap
	lose_sukuna.base_speed = 999
	lose_core.battle_logger.reset()
	_helper.run_turn(
		lose_core,
		lose_state,
		lose_content,
		_helper.build_ultimate_command(lose_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_ultimate_command(lose_core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
	)
	if lose_state.field_state == null or lose_state.field_state.field_def_id != "sukuna_malevolent_shrine_field":
		return harness.fail_result("领域对拼时 MP 更高的一方必须保留领域")
	if int(lose_gojo.stat_stages.get("sp_attack", 0)) != 0:
		return harness.fail_result("Gojo 对拼失败时不应获得领域绑定增幅")
	if _helper.has_rule_mod_apply_on_target(lose_core.battle_logger.event_log, lose_sukuna.unit_instance_id):
		return harness.fail_result("Gojo 对拼失败时不应再追加行动封锁")
	if _helper.find_field_clash_event(lose_core.battle_logger.event_log) == null:
		return harness.fail_result("领域对拼结果必须写入日志")

	var win_payload = _helper.build_gojo_vs_sukuna_state(harness, 2206)
	if win_payload.has("error"):
		return harness.fail_result(str(win_payload["error"]))
	var win_core = win_payload["core"]
	var win_content = win_payload["content_index"]
	var win_state = win_payload["battle_state"]
	var win_gojo = win_state.get_side("P1").get_active_unit()
	var win_sukuna = win_state.get_side("P2").get_active_unit()
	win_gojo.current_mp = win_gojo.max_mp
	win_gojo.ultimate_points = win_gojo.ultimate_points_cap
	win_sukuna.current_mp = 80
	win_sukuna.ultimate_points = win_sukuna.ultimate_points_cap
	win_sukuna.base_speed = 999
	win_core.battle_logger.reset()
	_helper.run_turn(
		win_core,
		win_state,
		win_content,
		_helper.build_ultimate_command(win_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_ultimate_command(win_core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
	)
	if win_state.field_state == null or win_state.field_state.field_def_id != "gojo_unlimited_void_field":
		return harness.fail_result("领域对拼胜者应把自己的领域真正立住")
	if int(win_gojo.stat_stages.get("sp_attack", 0)) != 1:
		return harness.fail_result("Gojo 领域成功立住后应获得领域绑定增幅")
	if int(win_sukuna.stat_stages.get("attack", 0)) != 0 or int(win_sukuna.stat_stages.get("sp_attack", 0)) != 0:
		return harness.fail_result("旧领域被打断时其领域绑定 buff 必须一并消失")
	if not _helper.has_rule_mod_apply_on_target(win_core.battle_logger.event_log, win_sukuna.unit_instance_id):
		return harness.fail_result("Gojo 只有在领域成功立住后才应追加行动封锁")
	return harness.pass_result()

func _test_field_clash_tie_replay_contract(harness) -> Dictionary:
	var first_result = _helper.run_tied_domain_clash(harness, 2207)
	if first_result.has("error"):
		return harness.fail_result(str(first_result["error"]))
	var second_result = _helper.run_tied_domain_clash(harness, 2207)
	if second_result.has("error"):
		return harness.fail_result(str(second_result["error"]))
	if first_result["field_id"] != second_result["field_id"]:
		return harness.fail_result("同 seed 的平 MP 领域对拼结果必须可复现")
	if abs(float(first_result["roll"]) - float(second_result["roll"])) > 0.000001:
		return harness.fail_result("同 seed 的平 MP 领域对拼随机值必须可复现")
	if String(first_result["summary"]) != String(second_result["summary"]):
		return harness.fail_result("领域对拼日志摘要必须和随机结果一起稳定复现")
	return harness.pass_result()

func _test_same_side_active_domain_recast_block_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2208)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
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
		return harness.fail_result("Gojo 首次开领域后应成功立场")
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	var legal_actions = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
	if legal_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
		return harness.fail_result("己方领域在场时，己方不应再次施放领域技能")
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		_helper.build_ultimate_command(core, 2, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 2, "P2", "P2-A"),
	])
	if not battle_state.battle_result.finished or battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		return harness.fail_result("领域重开非法时，手动提交领域技能应在选指阶段 fail-fast")
	return harness.pass_result()

func _test_opponent_domain_cast_still_legal_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sukuna_state(harness, 2209)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var sukuna_unit = battle_state.get_side("P2").get_active_unit()
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
		return harness.fail_result("Gojo 首次开领域后应成功立场")
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	var p2_legal_actions = core.legal_action_service.get_legal_actions(battle_state, "P2", content_index)
	if not p2_legal_actions.legal_ultimate_ids.has("sukuna_fukuma_mizushi"):
		return harness.fail_result("对手领域在场时，本方仍应允许施放自己的领域技能")
	gojo_unit.current_mp = 20
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_wait_command(core, 2, "P1", "P1-A"),
		_helper.build_ultimate_command(core, 2, "P2", "P2-A", "sukuna_fukuma_mizushi")
	)
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sukuna_malevolent_shrine_field":
		return harness.fail_result("对手应能通过领域对抗替换掉现有领域")
	return harness.pass_result()

func _test_same_turn_dual_domain_not_cancelled_by_action_lock_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sukuna_state(harness, 2210)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var sukuna_unit = battle_state.get_side("P2").get_active_unit()
	gojo_unit.base_speed = 999
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	core.battle_logger.reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
	)
	if _helper.find_field_clash_event(core.battle_logger.event_log) == null:
		return harness.fail_result("双方同回合施放领域时，必须进入领域对拼")
	if _helper.has_action_cancelled_pre_start_on_actor(core.battle_logger.event_log, sukuna_unit.unit_instance_id):
		return harness.fail_result("同回合同步开领域时，后手领域技能不应被 action_lock 直接取消")
	return harness.pass_result()

func _test_normal_field_cannot_replace_active_domain_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2211)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var p2_actions = core.legal_action_service.get_legal_actions(battle_state, "P2", content_index)
	if not p2_actions.legal_skill_ids.has("sample_field_call"):
		return harness.fail_result("样例单位应可施放普通 field 技能用于领域阻断回归")
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
		return harness.fail_result("Gojo 首次开领域后应成功立场")
	core.battle_logger.reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_wait_command(core, 2, "P1", "P1-A"),
		_helper.build_skill_command(core, 2, "P2", "P2-A", "sample_field_call")
	)
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		return harness.fail_result("普通 field 技能不应覆盖当前生效的领域")
	if not _helper.has_domain_block_log(core.battle_logger.event_log, "sample_focus_field"):
		return harness.fail_result("普通 field 被领域阻断时应写出可回放日志")
	return harness.pass_result()

func _test_domain_replaces_normal_field_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2212)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var p2_actions = core.legal_action_service.get_legal_actions(battle_state, "P2", content_index)
	if not p2_actions.legal_skill_ids.has("sample_field_call"):
		return harness.fail_result("样例单位应可施放普通 field 技能用于领域替换回归")
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		_helper.build_wait_command(core, 1, "P1", "P1-A"),
		_helper.build_skill_command(core, 1, "P2", "P2-A", "sample_field_call")
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sample_focus_field":
		return harness.fail_result("普通 field 技能应先正常立场")
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	core.battle_logger.reset()
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		_helper.build_ultimate_command(core, 2, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 2, "P2", "P2-A")
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		return harness.fail_result("领域技能应直接替换在场普通 field")
	if _helper.find_field_clash_event(core.battle_logger.event_log) != null:
		return harness.fail_result("领域替换普通 field 时不应写出领域对拼日志")
	if _helper.has_domain_block_log(core.battle_logger.event_log, "sample_focus_field"):
		return harness.fail_result("领域替换普通 field 时不应写出普通 field 被阻断日志")
	return harness.pass_result()

func _test_active_domain_missing_creator_fails_fast_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sukuna_state(harness, 2213)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var invalid_field = FieldStateScript.new()
	invalid_field.field_def_id = "gojo_unlimited_void_field"
	invalid_field.instance_id = "test_invalid_domain_field"
	invalid_field.creator = "missing_creator"
	invalid_field.remaining_turns = 2
	battle_state.field_state = invalid_field
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		_helper.build_wait_command(core, 1, "P1", "P1-A"),
		_helper.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if not battle_state.battle_result.finished or battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("active domain 缺失 creator 时必须 fail-fast 为 invalid_state_corruption")
	return harness.pass_result()

func _test_active_field_missing_creator_local_guard_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 22131)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var invalid_field = FieldStateScript.new()
	invalid_field.field_def_id = "sample_focus_field"
	invalid_field.instance_id = "test_invalid_local_field"
	invalid_field.creator = ""
	invalid_field.remaining_turns = 2
	battle_state.field_state = invalid_field
	var invalid_code = core.field_service.break_field_if_creator_inactive(
		battle_state,
		content_index,
		battle_state.chain_context
	)
	if invalid_code != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("field_service local path should fail-fast when creator is empty")
	return harness.pass_result()

func _test_same_side_domain_recast_main_path_fails_fast_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2214)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
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
		return harness.fail_result("前置条件失败：Gojo 首次开领域后应成功立场")
	var before_field_instance_id := String(battle_state.field_state.instance_id)
	var before_field_creator := String(battle_state.field_state.creator)
	var apply_effect = content_index.effects.get("gojo_apply_domain_field", null)
	if apply_effect == null or apply_effect.payloads.is_empty():
		return harness.fail_result("前置条件失败：缺少 gojo_apply_domain_field 资源")
	var effect_event = EffectEventScript.new()
	effect_event.event_id = "test_same_side_domain_recast_main_path"
	effect_event.trigger_name = "on_hit"
	effect_event.priority = 5
	effect_event.source_instance_id = "test_same_side_domain_recast_action"
	effect_event.source_kind_order = 2
	effect_event.source_order_speed_snapshot = gojo_unit.base_speed
	effect_event.effect_definition_id = "gojo_apply_domain_field"
	effect_event.owner_id = gojo_unit.unit_instance_id
	core.battle_logger.reset()
	var invalid_code = core.field_apply_service.apply_field(
		apply_effect,
		apply_effect.payloads[0],
		effect_event,
		battle_state,
		content_index
	)
	if invalid_code != ErrorCodesScript.INVALID_STATE_CORRUPTION:
		return harness.fail_result("同侧领域重开若进入 field clash 主路径必须 fail-fast 为 invalid_state_corruption")
	if battle_state.field_state == null or String(battle_state.field_state.instance_id) != before_field_instance_id or String(battle_state.field_state.creator) != before_field_creator:
		return harness.fail_result("同侧领域重开 fail-fast 后不应刷新 active field 状态")
	if _helper.find_field_clash_event(core.battle_logger.event_log) != null:
		return harness.fail_result("同侧领域重开 fail-fast 后不应写出领域对拼日志")
	return harness.pass_result()
