extends "res://test/suites/gojo_murasaki/shared.gd"

func test_gojo_murasaki_no_recoil_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1229)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
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
		fail("茈触发追加段后不应对五条悟造成反噬伤害")
		return
	if _count_target_damage_events(core.service("battle_logger").event_log, gojo_unit.unit_instance_id) != 0:
		fail("茈结算后不应给五条悟自己写入伤害事件")
		return

func test_gojo_murasaki_base_kill_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1207)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
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
		fail("茈本体先击杀时不应再触发追加段")
		return

func test_gojo_murasaki_burst_kill_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1208)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
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
		fail("茈追加段击杀时仍应保留第二段伤害结算")
		return
	if _has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE
	):
		fail("茈追加段击杀后清标记应静默跳过，不能报 invalid_battle")
		return

func test_gojo_murasaki_retargeted_switch_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1209)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
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
		fail("target switch should complete before priority -1 茈")
		return
	if _count_target_damage_events(core.service("battle_logger").event_log, new_target.unit_instance_id) != 1:
		fail("原目标先换下时，茈应命中新 active 且只打本体")
		return
	if _count_target_damage_events(core.service("battle_logger").event_log, original_target.unit_instance_id) != 0:
		fail("原目标离场后不应继续承受茈伤害")
		return

