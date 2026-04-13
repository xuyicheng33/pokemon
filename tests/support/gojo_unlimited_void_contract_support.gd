extends RefCounted
class_name GojoUnlimitedVoidContractSupport

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func run_failed_clash_does_not_revive_action_lock_contract(harness) -> Dictionary:
	return run_failed_clash_does_not_revive_action_lock_contract_for_matchup(harness, "gojo_vs_sukuna", 1216)

@warning_ignore("shadowed_global_identifier")
func run_failed_clash_does_not_revive_action_lock_contract_for_matchup(harness, matchup_id: String, seed: int) -> Dictionary:
	var state_payload = _support.build_gojo_matchup_state(harness, matchup_id, seed)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = _support.find_unit_on_side(battle_state, "P1", "gojo_satoru")
	if gojo_unit == null:
		gojo_unit = _support.find_unit_on_side(battle_state, "P2", "gojo_satoru")
	var sukuna_unit = _support.find_unit_on_side(battle_state, "P1", "sukuna")
	if sukuna_unit == null:
		sukuna_unit = _support.find_unit_on_side(battle_state, "P2", "sukuna")
	if gojo_unit == null or sukuna_unit == null:
		return harness.fail_result("missing gojo/sukuna active units for unlimited void clash contract")
	var gojo_side_id := _side_id_for_public_id(String(gojo_unit.public_id))
	var sukuna_side_id := _side_id_for_public_id(String(sukuna_unit.public_id))
	gojo_unit.current_mp = 80
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	gojo_unit.base_speed = 999
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_ultimate_command(core, 1, gojo_side_id, String(gojo_unit.public_id), "gojo_unlimited_void"),
		_support.build_ultimate_command(core, 1, sukuna_side_id, String(sukuna_unit.public_id), "sukuna_fukuma_mizushi"),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sukuna_malevolent_shrine_field":
		return harness.fail_result("Gojo 对拼失败时，最终立场的应是宿傩领域")
	if not _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_FIELD_CLASH
	):
		return harness.fail_result("Gojo 对拼失败时仍必须写出领域对拼日志")
	if _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and ev.target_instance_id == sukuna_unit.unit_instance_id
	):
		return harness.fail_result("Gojo 对拼失败后，不应把宿傩本回合已入队的领域动作误写成 cancelled_pre_start")
	if _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and ev.target_instance_id == sukuna_unit.unit_instance_id
	):
		return harness.fail_result("Gojo 对拼失败后，不应残留或复活无量空处的 action_lock")
	if not _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_CAST and ev.actor_id == sukuna_unit.unit_instance_id
		):
			return harness.fail_result("Gojo 对拼失败后，宿傩原本已入队的领域动作应继续正常执行")
	return harness.pass_result()

func run_expire_removes_field_buff_contract(harness) -> Dictionary:
	return run_expire_removes_field_buff_contract_for_matchup(harness, "gojo_vs_sukuna", 1218)

@warning_ignore("shadowed_global_identifier")
func run_expire_removes_field_buff_contract_for_matchup(harness, matchup_id: String, seed: int) -> Dictionary:
	var state_payload = _support.build_gojo_matchup_state(harness, matchup_id, seed)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = _support.find_unit_on_side(battle_state, "P1", "gojo_satoru")
	if gojo_unit == null:
		gojo_unit = _support.find_unit_on_side(battle_state, "P2", "gojo_satoru")
	if gojo_unit == null:
		return harness.fail_result("missing gojo active unit for unlimited void expire cleanup contract")
	var gojo_side_id := _side_id_for_public_id(String(gojo_unit.public_id))
	var opponent_side_id := "P2" if gojo_side_id == "P1" else "P1"
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_ultimate_command(core, 1, gojo_side_id, String(gojo_unit.public_id), "gojo_unlimited_void"),
		_support.build_wait_command(core, 1, opponent_side_id, "%s-A" % opponent_side_id),
	])
	if int(gojo_unit.stat_stages.get("sp_attack", 0)) != 1:
		return harness.fail_result("无量空处立住后应先给自己 sp_attack +1")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_wait_command(core, 2, gojo_side_id, String(gojo_unit.public_id)),
		_support.build_wait_command(core, 2, opponent_side_id, "%s-A" % opponent_side_id),
	])
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_wait_command(core, 3, gojo_side_id, String(gojo_unit.public_id)),
		_support.build_wait_command(core, 3, opponent_side_id, "%s-A" % opponent_side_id),
	])
	if battle_state.field_state != null:
		return harness.fail_result("无量空处应在第 3 回合结束时自然到期")
	if int(gojo_unit.stat_stages.get("sp_attack", 0)) != 0:
		return harness.fail_result("无量空处自然到期后应回收领域绑定的 sp_attack 增幅")
	if not _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE
	):
			return harness.fail_result("无量空处自然到期时应写出 field_expire 日志")
	return harness.pass_result()

func run_break_removes_field_buff_contract(harness) -> Dictionary:
	return run_break_removes_field_buff_contract_for_matchup(harness, "gojo_vs_sukuna", 1219)

@warning_ignore("shadowed_global_identifier")
func run_break_removes_field_buff_contract_for_matchup(harness, matchup_id: String, seed: int) -> Dictionary:
	var state_payload = _support.build_gojo_matchup_state(harness, matchup_id, seed)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = _support.find_unit_on_side(battle_state, "P1", "gojo_satoru")
	if gojo_unit == null:
		gojo_unit = _support.find_unit_on_side(battle_state, "P2", "gojo_satoru")
	if gojo_unit == null:
		return harness.fail_result("missing gojo active unit for unlimited void break cleanup contract")
	var gojo_side_id := _side_id_for_public_id(String(gojo_unit.public_id))
	var opponent_side_id := "P2" if gojo_side_id == "P1" else "P1"
	var bench_public_id := "%s-B" % gojo_side_id
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_ultimate_command(core, 1, gojo_side_id, String(gojo_unit.public_id), "gojo_unlimited_void"),
		_support.build_wait_command(core, 1, opponent_side_id, "%s-A" % opponent_side_id),
	])
	if int(gojo_unit.stat_stages.get("sp_attack", 0)) != 1:
		return harness.fail_result("无量空处立住后应先给自己 sp_attack +1")
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_switch_command(core, 2, gojo_side_id, String(gojo_unit.public_id), bench_public_id),
		_support.build_wait_command(core, 2, opponent_side_id, "%s-A" % opponent_side_id),
	])
	if battle_state.field_state != null:
		return harness.fail_result("无量空处 creator 离场时应立刻打断")
	if int(gojo_unit.stat_stages.get("sp_attack", 0)) != 0:
		return harness.fail_result("无量空处被打断后应立刻回收领域绑定的 sp_attack 增幅")
	if _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE
	):
		return harness.fail_result("无量空处被打断时不应误写成自然到期")
	return harness.pass_result()

func _side_id_for_public_id(public_id: String) -> String:
	return String(public_id).split("-", true, 1)[0]
