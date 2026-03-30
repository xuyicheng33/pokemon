extends RefCounted
class_name GojoSetupAndMarkersSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("gojo_content_and_setup_contract", failures, Callable(self, "_test_gojo_content_and_setup_contract").bind(harness))
    runner.run_test("gojo_first_turn_mp_contract", failures, Callable(self, "_test_gojo_first_turn_mp_contract").bind(harness))
    runner.run_test("gojo_ao_hit_contract", failures, Callable(self, "_test_gojo_ao_hit_contract").bind(harness))
    runner.run_test("gojo_ao_miss_contract", failures, Callable(self, "_test_gojo_ao_miss_contract").bind(harness))
    runner.run_test("gojo_aka_hit_contract", failures, Callable(self, "_test_gojo_aka_hit_contract").bind(harness))
    runner.run_test("gojo_aka_miss_contract", failures, Callable(self, "_test_gojo_aka_miss_contract").bind(harness))
    runner.run_test("gojo_marker_switch_lifecycle_contract", failures, Callable(self, "_test_gojo_marker_switch_lifecycle_contract").bind(harness))
    runner.run_test("gojo_marker_refresh_contract", failures, Callable(self, "_test_gojo_marker_refresh_contract").bind(harness))
func _test_gojo_content_and_setup_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var gojo = content_index.units.get("gojo_satoru", null)
    if gojo == null:
        return harness.fail_result("missing gojo unit definition")
    if gojo.skill_ids != PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki"]):
        return harness.fail_result("gojo default loadout must stay fixed as 苍/赫/茈")
    if gojo.candidate_skill_ids != PackedStringArray(["gojo_ao", "gojo_aka", "gojo_murasaki", "gojo_reverse_ritual"]):
        return harness.fail_result("gojo candidate skill pool should stay fixed as 苍/赫/茈/反转术式")
    if gojo.ultimate_skill_id != "gojo_unlimited_void":
        return harness.fail_result("gojo ultimate should stay fixed as 无量空处")
    if gojo.passive_skill_id != "gojo_mugen":
        return harness.fail_result("gojo passive should stay fixed as 无下限")
    var gojo_vs_sukuna = sample_factory.build_gojo_vs_sukuna_setup()
    if gojo_vs_sukuna.sides[0].unit_definition_ids[0] != "gojo_satoru" or gojo_vs_sukuna.sides[1].unit_definition_ids[0] != "sukuna":
        return harness.fail_result("gojo vs sukuna sample setup should place Gojo and Sukuna on active slots")
    var ritual_loadout: PackedStringArray = PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
    var gojo_vs_sample = sample_factory.build_gojo_vs_sample_setup({"P1": {0: ritual_loadout}})
    if gojo_vs_sample.sides[0].unit_definition_ids[0] != "gojo_satoru" or gojo_vs_sample.sides[1].unit_definition_ids[0] != "sample_pyron":
        return harness.fail_result("gojo vs sample setup should expose Gojo and sample unit on active slots")
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1201, gojo_vs_sample)
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    if gojo_unit == null or gojo_unit.regular_skill_ids != ritual_loadout:
        return harness.fail_result("gojo runtime loadout should mirror setup override")
    var legal_actions = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not legal_actions.legal_skill_ids.has("gojo_reverse_ritual") or legal_actions.legal_skill_ids.has("gojo_murasaki"):
        return harness.fail_result("gojo setup override should expose 反转术式 and hide 茈")
    return harness.pass_result()
func _test_gojo_first_turn_mp_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 1202, sample_factory.build_gojo_vs_sample_setup())
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    if gojo_unit == null:
        return harness.fail_result("missing gojo active unit")
    if gojo_unit.current_mp != 64:
        return harness.fail_result("gojo first actionable turn mp should be 64, got %d" % gojo_unit.current_mp)
    return harness.pass_result()
func _test_gojo_ao_hit_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1203)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_ao"].accuracy = 100
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if int(gojo_unit.stat_stages.get("speed", 0)) != 1:
        return harness.fail_result("苍命中后应给自己 speed +1")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 1:
        return harness.fail_result("苍命中后应给目标挂上苍标记")
    return harness.pass_result()

func _test_gojo_ao_miss_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1221)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_ao"].accuracy = 0
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if int(gojo_unit.stat_stages.get("speed", 0)) != 0:
        return harness.fail_result("苍 miss 时不应给自己 speed +1")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 0:
        return harness.fail_result("苍 miss 时不应给目标挂上苍标记")
    if not _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_MISS and ev.target_instance_id == target_unit.unit_instance_id
    ):
        return harness.fail_result("苍 miss 时应写出 ACTION_MISS")
    return harness.pass_result()
func _test_gojo_aka_hit_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1204)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_aka"].accuracy = 100
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_aka"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if int(target_unit.stat_stages.get("speed", 0)) != -1:
        return harness.fail_result("赫命中后应给目标 speed -1")
    if _count_effect_instances(target_unit, "gojo_aka_mark") != 1:
        return harness.fail_result("赫命中后应给目标挂上赫标记")
    return harness.pass_result()

func _test_gojo_aka_miss_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1222)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_aka"].accuracy = 0
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_aka"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if int(target_unit.stat_stages.get("speed", 0)) != 0:
        return harness.fail_result("赫 miss 时不应给目标 speed -1")
    if _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
        return harness.fail_result("赫 miss 时不应给目标挂上赫标记")
    if not _has_event(core.battle_logger.event_log, func(ev):
        return ev.event_type == EventTypesScript.ACTION_MISS and ev.target_instance_id == target_unit.unit_instance_id
    ):
        return harness.fail_result("赫 miss 时应写出 ACTION_MISS")
    return harness.pass_result()

func _test_gojo_marker_switch_lifecycle_contract(harness) -> Dictionary:
    var leave_target_payload = _build_gojo_vs_sample_state(harness, 1218)
    if leave_target_payload.has("error"):
        return harness.fail_result(str(leave_target_payload["error"]))
    var core = leave_target_payload["core"]
    var content_index = leave_target_payload["content_index"]
    var battle_state = leave_target_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    _apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_wait_command(core, 1, "P1", "P1-A"),
        _build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
    ])
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
        return harness.fail_result("标记持有者离场时应清掉双标记")
    var leave_gojo_payload = _build_gojo_vs_sample_state(harness, 1219)
    if leave_gojo_payload.has("error"):
        return harness.fail_result(str(leave_gojo_payload["error"]))
    var core_2 = leave_gojo_payload["core"]
    var content_index_2 = leave_gojo_payload["content_index"]
    var battle_state_2 = leave_gojo_payload["battle_state"]
    var gojo_unit_2 = battle_state_2.get_side("P1").get_active_unit()
    var target_unit_2 = battle_state_2.get_side("P2").get_active_unit()
    _apply_gojo_double_marks(core_2, content_index_2, battle_state_2, target_unit_2, gojo_unit_2.unit_instance_id, gojo_unit_2.base_speed)
    core_2.turn_loop_controller.run_turn(battle_state_2, content_index_2, [
        _build_switch_command(core_2, 1, "P1", "P1-A", "P1-B"),
        _build_wait_command(core_2, 1, "P2", "P2-A"),
    ])
    if _count_effect_instances(target_unit_2, "gojo_ao_mark") != 1 or _count_effect_instances(target_unit_2, "gojo_aka_mark") != 1:
        return harness.fail_result("Gojo 自己离场时不应清掉目标身上的双标记")
    return harness.pass_result()
func _test_gojo_marker_refresh_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1220)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_ao"].accuracy = 100
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    var first_mark = _find_effect_instance(target_unit, "gojo_ao_mark")
    if first_mark == null or first_mark.remaining != 2:
        return harness.fail_result("苍标记首回合施加后应在 turn_end 后剩余 2")
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_wait_command(core, 2, "P1", "P1-A"),
        _build_wait_command(core, 2, "P2", "P2-A"),
    ])
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 3, "P1", "P1-A", "gojo_ao"),
        _build_wait_command(core, 3, "P2", "P2-A"),
    ])
    var refreshed_mark = _find_effect_instance(target_unit, "gojo_ao_mark")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 1:
        return harness.fail_result("苍标记 refresh 语义下不应并行出第二层同名标记")
    if refreshed_mark == null or refreshed_mark.remaining != 2:
        return harness.fail_result("苍标记 refresh 后应重置持续时间，而不是继续沿用旧剩余回合")
    return harness.pass_result()

func _build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
    return _support.build_gojo_vs_sample_state(harness, seed)

func _build_sample_vs_gojo_state(harness, seed: int, use_sukuna: bool) -> Dictionary:
    return _support.build_sample_vs_gojo_state(harness, seed, use_sukuna)

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
