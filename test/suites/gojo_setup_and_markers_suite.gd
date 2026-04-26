extends "res://tests/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()


func test_gojo_content_and_setup_contract() -> void:
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
	var gojo = content_index.units.get("gojo_satoru", null)
	if gojo == null:
		fail("missing gojo unit definition")
		return
	if gojo.skill_ids != PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"]):
		fail("gojo default loadout must stay fixed as 苍/赫/茈")
		return
	if gojo.candidate_skill_ids != PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"]):
		fail("gojo candidate skill pool should stay fixed as 苍/赫/茈/反转术式")
		return
	if gojo.ultimate_skill_id != "gojo_unlimited_void":
		fail("gojo ultimate should stay fixed as 无量空处")
		return
	if gojo.passive_skill_id != "gojo_mugen":
		fail("gojo passive should stay fixed as 无下限")
		return
	var gojo_vs_sukuna = _harness.build_setup_by_matchup_id(sample_factory, "gojo_vs_sukuna")
	if gojo_vs_sukuna.sides[0].unit_definition_ids[0] != "gojo_satoru" or gojo_vs_sukuna.sides[1].unit_definition_ids[0] != "sukuna":
		fail("gojo vs sukuna sample setup should place Gojo and Sukuna on active slots")
		return
	var ritual_loadout: PackedStringArray = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
	var gojo_vs_sample = _harness.build_setup_by_matchup_id(sample_factory, "gojo_vs_sample", {"P1": {0: ritual_loadout}})
	if gojo_vs_sample.sides[0].unit_definition_ids[0] != "gojo_satoru" or gojo_vs_sample.sides[1].unit_definition_ids[0] != "sample_pyron":
		fail("gojo vs sample setup should expose Gojo and sample unit on active slots")
		return
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 1201, gojo_vs_sample)
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	if gojo_unit == null or gojo_unit.regular_skill_ids != ritual_loadout:
		fail("gojo runtime loadout should mirror setup override")
		return
	var legal_actions = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if not legal_actions.legal_skill_ids.has("gojo_reverse_ritual") or legal_actions.legal_skill_ids.has("gojo_murasaki"):
		fail("gojo setup override should expose 反转术式 and hide 茈")
		return

func test_gojo_first_turn_mp_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 1202, _harness.build_setup_by_matchup_id(sample_factory, "gojo_vs_sample"))
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	if gojo_unit == null:
		fail("missing gojo active unit")
		return
	if gojo_unit.current_mp != 64:
		fail("gojo first actionable turn mp should be 64, got %d" % gojo_unit.current_mp)
		return

func test_gojo_ao_hit_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1203)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_ao"].accuracy = 100
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if int(gojo_unit.stat_stages.get("speed", 0)) != 1:
		fail("苍命中后应给自己 speed +1")
		return
	if _count_effect_instances(target_unit, "gojo_ao_mark") != 1:
		fail("苍命中后应给目标挂上苍标记")
		return

func test_gojo_ao_miss_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1221)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_ao"].accuracy = 0
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if int(gojo_unit.stat_stages.get("speed", 0)) != 0:
		fail("苍 miss 时不应给自己 speed +1")
		return
	if _count_effect_instances(target_unit, "gojo_ao_mark") != 0:
		fail("苍 miss 时不应给目标挂上苍标记")
		return
	if not _has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_MISS and ev.target_instance_id == target_unit.unit_instance_id
	):
		fail("苍 miss 时应写出 ACTION_MISS")
		return

func test_gojo_aka_hit_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1204)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_aka"].accuracy = 100
	var target_unit = battle_state.get_side("P2").get_active_unit()
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_aka"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if int(target_unit.stat_stages.get("speed", 0)) != -1:
		fail("赫命中后应给目标 speed -1")
		return
	if _count_effect_instances(target_unit, "gojo_aka_mark") != 1:
		fail("赫命中后应给目标挂上赫标记")
		return

func test_gojo_aka_miss_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1222)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_aka"].accuracy = 0
	var target_unit = battle_state.get_side("P2").get_active_unit()
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_aka"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	if int(target_unit.stat_stages.get("speed", 0)) != 0:
		fail("赫 miss 时不应给目标 speed -1")
		return
	if _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
		fail("赫 miss 时不应给目标挂上赫标记")
		return
	if not _has_event(core.service("battle_logger").event_log, func(ev):
		return ev.event_type == EventTypesScript.ACTION_MISS and ev.target_instance_id == target_unit.unit_instance_id
	):
		fail("赫 miss 时应写出 ACTION_MISS")
		return

func test_gojo_marker_switch_lifecycle_contract() -> void:
	var leave_target_payload = _build_gojo_vs_sample_state(_harness, 1218)
	if leave_target_payload.has("error"):
		fail(str(leave_target_payload["error"]))
		return
	var core = leave_target_payload["core"]
	var content_index = leave_target_payload["content_index"]
	var battle_state = leave_target_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	var target_unit = battle_state.get_side("P2").get_active_unit()
	_apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_wait_command(core, 1, "P1", "P1-A"),
		_build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
	])
	if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
		fail("标记持有者离场时应清掉双标记")
		return
	var leave_gojo_payload = _build_gojo_vs_sample_state(_harness, 1219)
	if leave_gojo_payload.has("error"):
		fail(str(leave_gojo_payload["error"]))
		return
	var core_2 = leave_gojo_payload["core"]
	var content_index_2 = leave_gojo_payload["content_index"]
	var battle_state_2 = leave_gojo_payload["battle_state"]
	var gojo_unit_2 = battle_state_2.get_side("P1").get_active_unit()
	var target_unit_2 = battle_state_2.get_side("P2").get_active_unit()
	_apply_gojo_double_marks(core_2, content_index_2, battle_state_2, target_unit_2, gojo_unit_2.unit_instance_id, gojo_unit_2.base_speed)
	core_2.service("turn_loop_controller").run_turn(battle_state_2, content_index_2, [
		_build_switch_command(core_2, 1, "P1", "P1-A", "P1-B"),
		_build_wait_command(core_2, 1, "P2", "P2-A"),
	])
	if _count_effect_instances(target_unit_2, "gojo_ao_mark") != 1 or _count_effect_instances(target_unit_2, "gojo_aka_mark") != 1:
		fail("Gojo 自己离场时不应清掉目标身上的双标记")
		return

func test_gojo_marker_refresh_contract() -> void:
	var state_payload = _build_gojo_vs_sample_state(_harness, 1220)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	content_index.skills["gojo_ao"].accuracy = 100
	var target_unit = battle_state.get_side("P2").get_active_unit()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
		_build_wait_command(core, 1, "P2", "P2-A"),
	])
	var first_mark = _find_effect_instance(target_unit, "gojo_ao_mark")
	if first_mark == null or first_mark.remaining != 2:
		fail("苍标记首回合施加后应在 turn_end 后剩余 2")
		return
	var first_source_instance_id := String(first_mark.source_instance_id)
	var first_source_speed_snapshot := int(first_mark.source_order_speed_snapshot)
	if String(first_mark.meta.get("source_owner_id", "")) != String(battle_state.get_side("P1").get_active_unit().unit_instance_id):
		fail("苍标记初次施加时应写入当前 Gojo 的 source_owner_id")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_wait_command(core, 2, "P1", "P1-A"),
		_build_wait_command(core, 2, "P2", "P2-A"),
	])
	var gojo_unit = battle_state.get_side("P1").get_active_unit()
	gojo_unit.base_speed = 321
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_build_skill_command(core, 3, "P1", "P1-A", "gojo_ao"),
		_build_wait_command(core, 3, "P2", "P2-A"),
	])
	var refreshed_mark = _find_effect_instance(target_unit, "gojo_ao_mark")
	if _count_effect_instances(target_unit, "gojo_ao_mark") != 1:
		fail("苍标记 refresh 语义下不应并行出第二层同名标记")
		return
	if refreshed_mark == null or refreshed_mark.remaining != 2:
		fail("苍标记 refresh 后应重置持续时间，而不是继续沿用旧剩余回合")
		return
	if String(refreshed_mark.source_instance_id) == first_source_instance_id:
		fail("苍标记 refresh 后应刷新来源 source_instance_id")
		return
	if int(refreshed_mark.source_order_speed_snapshot) == first_source_speed_snapshot:
		fail("苍标记 refresh 后应刷新来源速度快照")
		return
	if String(refreshed_mark.meta.get("source_owner_id", "")) != String(gojo_unit.unit_instance_id):
		fail("苍标记 refresh 后应继续保留当前 Gojo 的 source_owner_id")
		return


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

func _apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id: String, source_speed: int) -> void:
	_support.apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id, source_speed)

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
