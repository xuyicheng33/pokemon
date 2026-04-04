extends RefCounted
class_name GojoUnlimitedVoidSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("gojo_unlimited_void_runtime_contract", failures, Callable(self, "_test_gojo_unlimited_void_runtime_contract").bind(harness))
	runner.run_test("gojo_unlimited_void_action_lock_wait_contract", failures, Callable(self, "_test_gojo_unlimited_void_action_lock_wait_contract").bind(harness))
	runner.run_test("gojo_unlimited_void_cancelled_pre_start_contract", failures, Callable(self, "_test_gojo_unlimited_void_cancelled_pre_start_contract").bind(harness))
	runner.run_test("gojo_unlimited_void_failed_clash_does_not_revive_action_lock_contract", failures, Callable(self, "_test_gojo_unlimited_void_failed_clash_does_not_revive_action_lock_contract").bind(harness))

func _test_gojo_unlimited_void_runtime_contract(harness) -> Dictionary:
	var state_payload = _support.build_gojo_vs_sample_state(harness, 1212)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	gojo_unit.current_mp = gojo_unit.max_mp
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_support.build_wait_command(core, 1, "P2", "P2-A"),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "gojo_unlimited_void_field":
		return harness.fail_result("无量空处命中后应施加无量空处领域")
	if int(gojo_unit.stat_stages.get("sp_attack", 0)) != 1:
		return harness.fail_result("无量空处领域成功立住时应给自己 sp_attack +1")
	if not _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_APPLY_FIELD \
			and ev.field_change != null \
			and ev.field_change.after_field_id == "gojo_unlimited_void_field"
	):
		return harness.fail_result("无量空处命中后应写出领域施加日志")
	if not _support.has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and ev.target_instance_id == target_unit.unit_instance_id
	):
		return harness.fail_result("无量空处命中后应对目标写出 deny all rule_mod 施加日志")
	content_index.skills["gojo_ao"].accuracy = 1
	var hit_command = _support.build_resolved_skill_command(core, 2, "P1", "P1-A", gojo_unit.unit_instance_id, "gojo_ao")
	var hit_info = core.service("action_cast_service").resolve_hit(hit_command, content_index.skills["gojo_ao"], target_unit, battle_state, content_index)
	if hit_info.get("hit_roll", "not-null") != null or abs(float(hit_info.get("hit_rate", -1.0)) - 1.0) > 0.0001:
		return harness.fail_result("无量空处领域内 creator_accuracy_override 应让 Gojo 的技能必中")
	return harness.pass_result()

func _test_gojo_unlimited_void_action_lock_wait_contract(harness) -> Dictionary:
	var state_payload = _support.build_gojo_vs_sample_state(harness, 1217)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	if gojo_unit == null or target_unit == null:
		return harness.fail_result("missing active units for unlimited void wait contract")
	var lock_effect = content_index.effects.get("gojo_domain_action_lock", null)
	if lock_effect == null or lock_effect.payloads.is_empty():
		return harness.fail_result("missing gojo_domain_action_lock effect definition")
	var lock_payload = lock_effect.payloads[0]
	if core.service("rule_mod_service").create_instance(
		lock_payload,
		{"scope": "unit", "id": target_unit.unit_instance_id},
		battle_state,
		"test_gojo_domain_action_lock_wait",
		0,
		gojo_unit.base_speed
	) == null:
		return harness.fail_result("failed to apply gojo domain action lock payload directly")
	var legal_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P2", content_index)
	if legal_actions == null:
		return harness.fail_result("failed to resolve legal actions under gojo domain action lock")
	if not legal_actions.wait_allowed or legal_actions.forced_command_type != "":
		return harness.fail_result("gojo domain action lock should still leave wait available")
	if not legal_actions.legal_skill_ids.is_empty() or not legal_actions.legal_ultimate_ids.is_empty() or not legal_actions.legal_switch_target_public_ids.is_empty():
		return harness.fail_result("gojo domain action lock should deny skills, ultimates, and switches while keeping wait")
	return harness.pass_result()

func _test_gojo_unlimited_void_cancelled_pre_start_contract(harness) -> Dictionary:
	var cases: Array = [
		{
			"name": "skill",
			"command": func(core): return _support.build_skill_command(core, 1, "P2", "P2-A", "sample_strike"),
			"expect_cancelled": true,
		},
		{
			"name": "ultimate",
			"command": func(core): return _support.build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
			"opponent": "sukuna",
			"expect_cancelled": false,
		},
		{
			"name": "switch",
			"command": func(core): return _support.build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
			"expect_cancelled": true,
		},
	]
	for i in range(cases.size()):
		var use_sukuna: bool = String(cases[i].get("opponent", "sample")) == "sukuna"
		var state_payload = _support.build_gojo_battle_state(harness, 1213 + i, use_sukuna, true)
		if state_payload.has("error"):
			return harness.fail_result(str(state_payload["error"]))
		var core = state_payload["core"]
		var content_index = state_payload["content_index"]
		var battle_state = state_payload["battle_state"]
		var gojo_unit = battle_state.get_side("P1").get_active_unit()
		gojo_unit.current_mp = gojo_unit.max_mp
		gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
		if use_sukuna:
			var sukuna_unit = battle_state.get_side("P2").get_active_unit()
			sukuna_unit.current_mp = sukuna_unit.max_mp
			sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
		core.service("battle_logger").reset()
		core.service("turn_loop_controller").run_turn(battle_state, content_index, [
			_support.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
			cases[i]["command"].call(core),
		])
		var opponent = _support.find_unit_on_side(battle_state, "P2", "sukuna" if use_sukuna else "sample_pyron")
		if opponent == null:
			return harness.fail_result("missing opponent unit for unlimited void cancel test")
		if bool(cases[i]["expect_cancelled"]):
			if not _support.has_event(core.service("battle_logger").event_log, func(ev):
				return ev.event_type == EventTypesScript.ACTION_CANCELLED_PRE_START and ev.target_instance_id == opponent.unit_instance_id
			):
				return harness.fail_result("无量空处先手命中后应把对方未开始的 %s 动作标记为 cancelled_pre_start" % cases[i]["name"])
			if _support.has_event(core.service("battle_logger").event_log, func(ev):
				return ev.event_type == EventTypesScript.ACTION_CAST and ev.actor_id == opponent.unit_instance_id
			):
				return harness.fail_result("被无量空处锁住的 %s 动作不应走到 ACTION_CAST" % cases[i]["name"])
			continue
		if not _support.has_event(core.service("battle_logger").event_log, func(ev):
			return ev.event_type == EventTypesScript.ACTION_CAST and ev.actor_id == opponent.unit_instance_id
		):
			return harness.fail_result("双方同回合开领域时，对手 %s 动作不应被 action_lock 抢先取消" % cases[i]["name"])
		if not _support.has_event(core.service("battle_logger").event_log, func(ev):
			return ev.event_type == EventTypesScript.EFFECT_FIELD_CLASH
		):
			return harness.fail_result("双方同回合开领域时必须写出领域对拼日志")
	return harness.pass_result()

func _test_gojo_unlimited_void_failed_clash_does_not_revive_action_lock_contract(harness) -> Dictionary:
	var state_payload = _support.build_gojo_battle_state(harness, 1216, true, true)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var sukuna_unit = battle_state.get_side("P2").get_active_unit()
	gojo_unit.current_mp = 80
	gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
	gojo_unit.base_speed = 999
	sukuna_unit.current_mp = sukuna_unit.max_mp
	sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_support.build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi"),
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
