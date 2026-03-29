extends RefCounted
class_name FieldLifecycleContractSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const UltimateFieldTestHelperScript := preload("res://tests/support/ultimate_field_test_helper.gd")

var _helper = UltimateFieldTestHelperScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("field_bound_stat_mod_restore_contract", failures, Callable(self, "_test_field_bound_stat_mod_restore_contract").bind(harness))
	runner.run_test("field_break_self_owner_contract", failures, Callable(self, "_test_field_break_self_owner_contract").bind(harness))

func _test_field_bound_stat_mod_restore_contract(harness) -> Dictionary:
	var gojo_payload = _helper.build_gojo_vs_sample_state(harness, 2212)
	if gojo_payload.has("error"):
		return harness.fail_result(str(gojo_payload["error"]))
	var gojo_core = gojo_payload["core"]
	var gojo_content = gojo_payload["content_index"]
	var gojo_state = gojo_payload["battle_state"]
	var gojo = gojo_state.get_side("P1").get_active_unit()
	gojo.current_mp = gojo.max_mp
	gojo.ultimate_points = gojo.ultimate_points_cap
	gojo.stat_stages["sp_attack"] = 2
	_helper.run_turn(
		gojo_core,
		gojo_state,
		gojo_content,
		_helper.build_ultimate_command(gojo_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(gojo_core, 1, "P2", "P2-A")
	)
	_helper.run_turn(gojo_core, gojo_state, gojo_content, _helper.build_wait_command(gojo_core, 2, "P1", "P1-A"), _helper.build_wait_command(gojo_core, 2, "P2", "P2-A"))
	_helper.run_turn(gojo_core, gojo_state, gojo_content, _helper.build_wait_command(gojo_core, 3, "P1", "P1-A"), _helper.build_wait_command(gojo_core, 3, "P2", "P2-A"))
	_helper.run_turn(gojo_core, gojo_state, gojo_content, _helper.build_wait_command(gojo_core, 4, "P1", "P1-A"), _helper.build_wait_command(gojo_core, 4, "P2", "P2-A"))
	if int(gojo.stat_stages.get("sp_attack", -99)) != 2:
		return harness.fail_result("Gojo 领域结束后必须回到开领域前的 sp_attack 阶段")

	var sukuna_payload = _helper.build_sukuna_vs_sample_state(harness, 2213)
	if sukuna_payload.has("error"):
		return harness.fail_result(str(sukuna_payload["error"]))
	var sukuna_core = sukuna_payload["core"]
	var sukuna_content = sukuna_payload["content_index"]
	var sukuna_state = sukuna_payload["battle_state"]
	var sukuna = sukuna_state.get_side("P1").get_active_unit()
	sukuna.current_mp = sukuna.max_mp
	sukuna.ultimate_points = sukuna.ultimate_points_cap
	sukuna.stat_stages["attack"] = 2
	sukuna.stat_stages["sp_attack"] = 2
	_helper.run_turn(
		sukuna_core,
		sukuna_state,
		sukuna_content,
		_helper.build_ultimate_command(sukuna_core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_helper.build_wait_command(sukuna_core, 1, "P2", "P2-A")
	)
	_helper.run_turn(sukuna_core, sukuna_state, sukuna_content, _helper.build_wait_command(sukuna_core, 2, "P1", "P1-A"), _helper.build_wait_command(sukuna_core, 2, "P2", "P2-A"))
	_helper.run_turn(sukuna_core, sukuna_state, sukuna_content, _helper.build_wait_command(sukuna_core, 3, "P1", "P1-A"), _helper.build_wait_command(sukuna_core, 3, "P2", "P2-A"))
	_helper.run_turn(sukuna_core, sukuna_state, sukuna_content, _helper.build_wait_command(sukuna_core, 4, "P1", "P1-A"), _helper.build_wait_command(sukuna_core, 4, "P2", "P2-A"))
	if int(sukuna.stat_stages.get("attack", -99)) != 2 or int(sukuna.stat_stages.get("sp_attack", -99)) != 2:
		return harness.fail_result("宿傩领域结束后必须回到开领域前的双攻阶段")
	return harness.pass_result()

func _test_field_break_self_owner_contract(harness) -> Dictionary:
	var state_payload = _helper.build_gojo_vs_sample_state(harness, 2214)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var actor = battle_state.get_side("P1").get_active_unit()
	actor.current_mp = 40
	_helper.register_self_break_field_test_content(content_index)
	actor.regular_skill_ids[0] = "test_self_break_field_call"
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_skill_command(core, 1, "P1", "P1-A", "test_self_break_field_call"),
		_helper.build_wait_command(core, 1, "P2", "P2-A")
	)
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "test_self_break_field":
		return harness.fail_result("自定义 field 应在测试里成功立场")
	core.battle_logger.reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_switch_command(core, 2, "P1", "P1-A", "P1-B"),
		_helper.build_wait_command(core, 2, "P2", "P2-A")
	)
	var break_after := -1
	for log_event in core.battle_logger.event_log:
		if log_event.event_type != EventTypesScript.EFFECT_RESOURCE_MOD or log_event.value_changes.is_empty():
			continue
		var value_change = log_event.value_changes[0]
		if log_event.trigger_name == "field_break" and log_event.target_instance_id == actor.unit_instance_id and String(value_change.resource_name) == "mp" and int(value_change.delta) == 5:
			break_after = int(value_change.after_value)
			break
	if break_after < 0:
		return harness.fail_result("field_break 的 self 效果应能作用到已离场但仍存活的领域创建者")
	if actor.current_mp != break_after:
		return harness.fail_result("field_break 的资源变化必须真实落到已离场创建者运行态上")
	return harness.pass_result()
