extends "res://test/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()


func test_gojo_murasaki_no_marks_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_no_marks_contract(_harness))

func test_gojo_murasaki_double_mark_burst_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_double_mark_burst_contract(_harness))

func test_gojo_murasaki_same_owner_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_same_owner_contract(_harness))

func test_gojo_murasaki_no_recoil_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_no_recoil_contract(_harness))

func test_gojo_murasaki_base_kill_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_base_kill_contract(_harness))

func test_gojo_murasaki_burst_kill_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_burst_kill_contract(_harness))

func test_gojo_murasaki_retargeted_switch_contract() -> void:
	_assert_legacy_result(_test_gojo_murasaki_retargeted_switch_contract(_harness))
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
func _test_gojo_murasaki_no_recoil_contract(harness) -> Dictionary:
	var state_payload = _build_gojo_vs_sample_state(harness, 1229)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_murasaki"].accuracy = 100
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	var before_hp: int = gojo_unit.current_hp
	_apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if gojo_unit.current_hp != before_hp:
		return harness.fail_result("茈触发追加段后不应对五条悟造成反噬伤害")
	if _count_target_damage_events(core.service("battle_logger").event_log, gojo_unit.unit_instance_id) != 0:
		return harness.fail_result("茈结算后不应给五条悟自己写入伤害事件")
	return harness.pass_result()
func _test_gojo_murasaki_base_kill_contract(harness) -> Dictionary:
	var state_payload = _build_gojo_vs_sample_state(harness, 1207)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_murasaki"].accuracy = 100
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	target_unit.current_hp = 30
	_apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if _count_target_damage_events(core.service("battle_logger").event_log, target_unit.unit_instance_id) != 1:
		return harness.fail_result("茈本体先击杀时不应再触发追加段")
	return harness.pass_result()
func _test_gojo_murasaki_burst_kill_contract(harness) -> Dictionary:
	var state_payload = _build_gojo_vs_sample_state(harness, 1208)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_murasaki"].accuracy = 100
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	target_unit.current_hp = 50
	_apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if _count_target_damage_events(core.service("battle_logger").event_log, target_unit.unit_instance_id) != 2:
		return harness.fail_result("茈追加段击杀时仍应保留第二段伤害结算")
	if _has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE
	):
		return harness.fail_result("茈追加段击杀后清标记应静默跳过，不能报 invalid_battle")
	return harness.pass_result()
func _test_gojo_murasaki_retargeted_switch_contract(harness) -> Dictionary:
	var state_payload = _build_gojo_vs_sample_state(harness, 1209)
	if state_payload.has("error"):
		return harness.fail_result(str(state_payload["error"]))
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_murasaki"].accuracy = 100
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var original_target = battle_state.get_side("P2").get_active_unit()
	_apply_gojo_double_marks(core, content_index, battle_state, original_target, gojo_unit.unit_instance_id, gojo_unit.base_speed)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
		_build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
	])
	var new_target = battle_state.get_side("P2").get_active_unit()
	if new_target == null or new_target.public_id != "P2-B":
		return harness.fail_result("target switch should complete before priority -1 茈")
	if _count_target_damage_events(core.service("battle_logger").event_log, new_target.unit_instance_id) != 1:
		return harness.fail_result("原目标先换下时，茈应命中新 active 且只打本体")
	if _count_target_damage_events(core.service("battle_logger").event_log, original_target.unit_instance_id) != 0:
		return harness.fail_result("原目标离场后不应继续承受茈伤害")
	return harness.pass_result()

@warning_ignore("shadowed_global_identifier")
func _build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
	return _support.build_gojo_vs_sample_state(harness, seed)

@warning_ignore("shadowed_global_identifier")
func _build_sample_vs_gojo_state(harness, seed: int, use_sukuna: bool) -> Dictionary:
	return _support.build_sample_vs_gojo_state(harness, seed, use_sukuna)

@warning_ignore("shadowed_global_identifier")
func _build_gojo_battle_state(harness, seed: int, use_sukuna: bool, gojo_on_p1: bool) -> Dictionary:
	return _support.build_gojo_battle_state(harness, seed, use_sukuna, gojo_on_p1)

func _build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _support.build_wait_command(core, turn_index, side_id, actor_public_id)

func _build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return _support.build_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func _build_resolved_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, actor_id: String, skill_id: String):
	return _support.build_resolved_skill_command(core, turn_index, side_id, actor_public_id, actor_id, skill_id)

func _build_accuracy_skill(skill_id: String, accuracy: int):
	return _support.build_accuracy_skill(skill_id, accuracy)

func _apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id: String, source_speed: int, source_owner_id: String = "") -> void:
	_support.apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id, source_speed, source_owner_id)

func _set_field_state(battle_state, field_id: String, creator_id: String) -> void:
	_support.set_field_state(battle_state, field_id, creator_id)

func _find_unit_on_side(battle_state, side_id: String, definition_id: String):
	return _support.find_unit_on_side(battle_state, side_id, definition_id)

func _find_effect_instance(unit_state, effect_id: String):
	return _support.find_effect_instance(unit_state, effect_id)

func _count_effect_instances(unit_state, effect_id: String) -> int:
	return _support.count_effect_instances(unit_state, effect_id)

func _count_rule_mod_instances(unit_state, mod_kind: String) -> int:
	return _support.count_rule_mod_instances(unit_state, mod_kind)

func _count_target_damage_events(event_log: Array, target_unit_id: String) -> int:
	return _support.count_target_damage_events(event_log, EventTypesScript.EFFECT_DAMAGE, target_unit_id)

func _has_event(event_log: Array, predicate: Callable) -> bool:
	return _support.has_event(event_log, predicate)

func _find_burst_damage_event(event_log: Array, target_unit_id: String, target_public_id: String):
	for ev in event_log:
		if ev.event_type != EventTypesScript.EFFECT_DAMAGE or ev.target_instance_id != target_unit_id:
			continue
		var summary := str(ev.payload_summary)
		if summary.begins_with("%s damage " % target_public_id):
			return ev
	return null

func _first_value_change(log_event):
	if log_event == null:
		return null
	if log_event.value_changes == null or log_event.value_changes.is_empty():
		return null
	return log_event.value_changes[0]

func _calc_formula_damage(core, battle_state, power: int, damage_kind: String, actor, target, combat_type_id: String) -> int:
	var attack_base: int = actor.base_attack
	var defense_base: int = target.base_defense
	var attack_stage: int = int(actor.stat_stages.get("attack", 0))
	var defense_stage: int = int(target.stat_stages.get("defense", 0))
	if damage_kind == "special":
		attack_base = actor.base_sp_attack
		defense_base = target.base_sp_defense
		attack_stage = int(actor.stat_stages.get("sp_attack", 0))
		defense_stage = int(target.stat_stages.get("sp_defense", 0))
	var attack_value = core.service("stat_calculator").calc_effective_stat(attack_base, attack_stage)
	var defense_value = core.service("stat_calculator").calc_effective_stat(defense_base, defense_stage)
	var effectiveness = core.service("combat_type_service").calc_effectiveness(combat_type_id, target.combat_type_ids)
	var final_multiplier = core.service("rule_mod_service").get_final_multiplier(battle_state, actor.unit_instance_id)
	return core.service("damage_service").apply_final_mod(
		core.service("damage_service").calc_base_damage(
			battle_state.battle_level,
			max(1, power),
			attack_value,
			defense_value
		),
		final_multiplier * effectiveness
	)
