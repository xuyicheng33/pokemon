extends "res://test/suites/gojo_murasaki/shared.gd"

func test_gojo_murasaki_no_marks_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_no_marks_contract(_harness))

func test_gojo_murasaki_double_mark_burst_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_double_mark_burst_contract(_harness))

func test_gojo_murasaki_same_owner_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_same_owner_contract(_harness))

func _test_gojo_murasaki_no_marks_contract(harness) -> Dictionary:
	var state_payload = _build_gojo_vs_sample_state(harness, 1205)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_murasaki"].accuracy = 100
	var target_unit = battle_state.get_side("P2").get_active_unit()
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if _count_target_damage_events(core.service("battle_logger").event_log, target_unit.unit_instance_id) != 1:
		return harness.fail_result("茈在无双标记时只能命中一次本体伤害")
	if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
		return harness.fail_result("茈在无双标记时不应误清或误造标记")
	return harness.pass_result()

func _test_gojo_murasaki_double_mark_burst_contract(harness) -> Dictionary:
	var state_payload = _build_gojo_vs_sample_state(harness, 1206)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_murasaki"].accuracy = 100
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	var murasaki_skill = content_index.skills["gojo_murasaki"]
	var burst_effect = content_index.effects.get("gojo_murasaki_conditional_burst", null)
	if burst_effect == null or burst_effect.payloads.is_empty():
		return harness.fail_result("茈追加段资源缺失：gojo_murasaki_conditional_burst")
	var burst_damage_payload = burst_effect.payloads[0]
	if not bool(burst_damage_payload.use_formula):
		return harness.fail_result("茈追加段伤害必须走公式结算（use_formula=true）")
	if str(burst_damage_payload.damage_kind) != "special":
		return harness.fail_result("茈追加段伤害类型必须为 special")
	if int(burst_damage_payload.amount) != 32:
		return harness.fail_result("茈追加段公式威力必须固定为 32")
	if str(murasaki_skill.combat_type_id) != "space":
		return harness.fail_result("茈追加段在 use_formula 链路下应继承技能 combat_type_id=space")
	var expected_burst_damage = _calc_formula_damage(
		core,
		battle_state,
		int(burst_damage_payload.amount),
		str(burst_damage_payload.damage_kind),
		gojo_unit,
		target_unit,
		str(murasaki_skill.combat_type_id)
	)
	var expected_type_effectiveness = core.service("combat_type_service").calc_effectiveness(
		str(murasaki_skill.combat_type_id),
		target_unit.combat_type_ids
	)
	_apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if _count_target_damage_events(core.service("battle_logger").event_log, target_unit.unit_instance_id) != 2:
		return harness.fail_result("茈在双标记时应追加第二段伤害")
	var burst_event = _find_burst_damage_event(core.service("battle_logger").event_log, target_unit.unit_instance_id, target_unit.public_id)
	if burst_event == null:
		return harness.fail_result("茈双标记时应写出追加段 payload_damage 的 EFFECT_DAMAGE")
	var burst_change = _first_value_change(burst_event)
	if burst_change == null:
		return harness.fail_result("茈追加段日志必须带 value_changes")
	if int(burst_change.delta) != -expected_burst_damage:
		return harness.fail_result("茈追加段伤害值应匹配 power=32 的公式结算")
	if abs(float(burst_event.type_effectiveness) - float(expected_type_effectiveness)) > 0.0001:
		return harness.fail_result("茈追加段应继承技能 combat_type_id=space 的克制倍率")
	if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
		return harness.fail_result("茈在双标记追加后应清掉双标记")
	return harness.pass_result()

func _test_gojo_murasaki_same_owner_contract(harness) -> Dictionary:
	var state_payload = _build_gojo_vs_sample_state(harness, 1230)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_murasaki"].accuracy = 100
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	_apply_gojo_double_marks(
		core,
		content_index,
		battle_state,
		target_unit,
		"test_mark_source",
		gojo_unit.base_speed,
		"other_gojo_owner"
	)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if _count_target_damage_events(core.service("battle_logger").event_log, target_unit.unit_instance_id) != 1:
		return harness.fail_result("茈只应消耗自己来源的双标记，异来源标记不应触发追加段")
	if _count_effect_instances(target_unit, "gojo_ao_mark") != 1 or _count_effect_instances(target_unit, "gojo_aka_mark") != 1:
		return harness.fail_result("异来源双标记未命中前置时不应被误清理")
	return harness.pass_result()
