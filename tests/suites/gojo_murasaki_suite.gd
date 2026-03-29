extends RefCounted
class_name GojoMurasakiSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("gojo_murasaki_no_marks_contract", failures, Callable(self, "_test_gojo_murasaki_no_marks_contract").bind(harness))
    runner.run_test("gojo_murasaki_double_mark_burst_contract", failures, Callable(self, "_test_gojo_murasaki_double_mark_burst_contract").bind(harness))
    runner.run_test("gojo_murasaki_base_kill_contract", failures, Callable(self, "_test_gojo_murasaki_base_kill_contract").bind(harness))
    runner.run_test("gojo_murasaki_burst_kill_contract", failures, Callable(self, "_test_gojo_murasaki_burst_kill_contract").bind(harness))
    runner.run_test("gojo_murasaki_retargeted_switch_contract", failures, Callable(self, "_test_gojo_murasaki_retargeted_switch_contract").bind(harness))
func _test_gojo_murasaki_no_marks_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 1205)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    content_index.skills["gojo_murasaki"].accuracy = 100
    var target_unit = battle_state.get_side("P2").get_active_unit()
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 1:
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
    _apply_gojo_double_marks(core, content_index, battle_state, target_unit, gojo_unit.unit_instance_id, gojo_unit.base_speed)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 2:
        return harness.fail_result("茈在双标记时应追加第二段伤害")
    if _count_effect_instances(target_unit, "gojo_ao_mark") != 0 or _count_effect_instances(target_unit, "gojo_aka_mark") != 0:
        return harness.fail_result("茈在双标记追加后应清掉双标记")
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 1:
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if _count_target_damage_events(core.battle_logger.event_log, target_unit.unit_instance_id) != 2:
        return harness.fail_result("茈追加段击杀时仍应保留第二段伤害结算")
    if _has_event(core.battle_logger.event_log, func(ev):
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
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_skill_command(core, 1, "P1", "P1-A", "gojo_murasaki"),
        _build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
    ])
    var new_target = battle_state.get_side("P2").get_active_unit()
    if new_target == null or new_target.public_id != "P2-B":
        return harness.fail_result("target switch should complete before priority -1 茈")
    if _count_target_damage_events(core.battle_logger.event_log, new_target.unit_instance_id) != 1:
        return harness.fail_result("原目标先换下时，茈应命中新 active 且只打本体")
    if _count_target_damage_events(core.battle_logger.event_log, original_target.unit_instance_id) != 0:
        return harness.fail_result("原目标离场后不应继续承受茈伤害")
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
