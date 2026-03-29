extends RefCounted
class_name UltimateFieldSuite

const EventTypesScript := preload("res://src/shared/event_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("ultimate_points_regular_skill_gain_contract", failures, Callable(self, "_test_ultimate_points_regular_skill_gain_contract").bind(harness))
    runner.run_test("ultimate_points_non_regular_switch_preserve_contract", failures, Callable(self, "_test_ultimate_points_non_regular_switch_preserve_contract").bind(harness))
    runner.run_test("ultimate_points_ultimate_legality_and_reset_contract", failures, Callable(self, "_test_ultimate_points_ultimate_legality_and_reset_contract").bind(harness))
    runner.run_test("field_clash_high_mp_and_success_only_followup_contract", failures, Callable(self, "_test_field_clash_high_mp_and_success_only_followup_contract").bind(harness))
    runner.run_test("field_clash_tie_replay_contract", failures, Callable(self, "_test_field_clash_tie_replay_contract").bind(harness))

func _test_ultimate_points_regular_skill_gain_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 2201)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var initial_snapshot = core.public_snapshot_builder.build_public_snapshot(battle_state, content_index)
    var p1_snapshot = _find_side_snapshot(initial_snapshot, "P1")
    if int(p1_snapshot.get("active_ultimate_points", -1)) != 0 \
    or int(p1_snapshot.get("active_ultimate_points_cap", -1)) != 3 \
    or int(p1_snapshot.get("active_ultimate_points_required", -1)) != 3:
        return harness.fail_result("公开快照必须暴露 Gojo 当前奥义点、上限与需求")
    content_index.skills["gojo_ao"].accuracy = 0
    core.battle_logger.reset()
    _run_turn(
        core,
        battle_state,
        content_index,
        _support.build_skill_command(core, 1, "P1", "P1-A", "gojo_ao"),
        _support.build_wait_command(core, 1, "P2", "P2-A")
    )
    if gojo_unit.ultimate_points != 1:
        return harness.fail_result("常规技能开始施放后即使 miss 也应获得 1 点奥义点")
    if not _has_ultimate_point_delta(core.battle_logger.event_log, 1, 1):
        return harness.fail_result("常规技能加点应写出独立 ultimate_points 资源变化日志")
    gojo_unit.ultimate_points = 2
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_skill_command(core, 2, "P1", "P1-A", "gojo_aka"),
        _support.build_wait_command(core, 2, "P2", "P2-A"),
    ])
    if gojo_unit.ultimate_points != 3:
        return harness.fail_result("奥义点应按角色上限封顶")
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_skill_command(core, 3, "P1", "P1-A", "gojo_aka"),
        _support.build_wait_command(core, 3, "P2", "P2-A"),
    ])
    if gojo_unit.ultimate_points != 3:
        return harness.fail_result("已满奥义点再次施放常规技能时不应溢出")
    if _has_ultimate_point_delta(core.battle_logger.event_log, 0, 3):
        return harness.fail_result("点数已满时不应再写出零变化 ultimate_points 日志")
    return harness.pass_result()

func _test_ultimate_points_non_regular_switch_preserve_contract(harness) -> Dictionary:
    var state_payload = _build_gojo_vs_sample_state(harness, 2202)
    if state_payload.has("error"):
        return harness.fail_result(str(state_payload["error"]))
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    gojo_unit.ultimate_points = 2
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_wait_command(core, 1, "P1", "P1-A"),
        _support.build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if gojo_unit.ultimate_points != 2:
        return harness.fail_result("wait 不应改变奥义点")
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_switch_command(core, 2, "P1", "P1-A", "P1-B"),
        _support.build_wait_command(core, 2, "P2", "P2-A"),
    ])
    if gojo_unit.ultimate_points != 2:
        return harness.fail_result("换下后奥义点必须保留在原角色运行态上")
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_switch_command(core, 3, "P1", "P1-B", "P1-A"),
        _support.build_wait_command(core, 3, "P2", "P2-A"),
    ])
    var reentered_gojo = battle_state.get_side("P1").get_active_unit()
    if reentered_gojo == null or reentered_gojo.definition_id != "gojo_satoru" or reentered_gojo.ultimate_points != 2:
        return harness.fail_result("换回后角色应带回原先保留的奥义点")
    return harness.pass_result()

func _test_ultimate_points_ultimate_legality_and_reset_contract(harness) -> Dictionary:
    var blocked_payload = _build_gojo_vs_sample_state(harness, 2203)
    if blocked_payload.has("error"):
        return harness.fail_result(str(blocked_payload["error"]))
    var blocked_core = blocked_payload["core"]
    var blocked_content = blocked_payload["content_index"]
    var blocked_state = blocked_payload["battle_state"]
    var blocked_gojo = blocked_state.get_side("P1").get_active_unit()
    blocked_gojo.current_mp = blocked_gojo.max_mp
    var blocked_actions = blocked_core.legal_action_service.get_legal_actions(blocked_state, "P1", blocked_content)
    if blocked_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
        return harness.fail_result("奥义点不足时不应把奥义列为合法动作")
    blocked_core.turn_loop_controller.run_turn(blocked_state, blocked_content, [
        _support.build_ultimate_command(blocked_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _support.build_wait_command(blocked_core, 1, "P2", "P2-A"),
    ])
    if not blocked_state.battle_result.finished or blocked_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return harness.fail_result("点数不足时手动提交奥义必须在选指阶段 fail-fast")

    var ready_payload = _build_gojo_vs_sample_state(harness, 2204)
    if ready_payload.has("error"):
        return harness.fail_result(str(ready_payload["error"]))
    var core = ready_payload["core"]
    var content_index = ready_payload["content_index"]
    var battle_state = ready_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    gojo_unit.current_mp = gojo_unit.max_mp
    gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
    var ready_actions = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not ready_actions.legal_ultimate_ids.has("gojo_unlimited_void"):
        return harness.fail_result("MP 与奥义点都满足时奥义必须合法")
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _support.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _support.build_wait_command(core, 1, "P2", "P2-A"),
    ])
    if gojo_unit.ultimate_points != 0:
        return harness.fail_result("奥义开始施放时必须清空奥义点")
    if not _has_ultimate_point_delta(core.battle_logger.event_log, -3, 0):
        return harness.fail_result("奥义清空点数必须写入资源变化日志")
    var post_snapshot = core.public_snapshot_builder.build_public_snapshot(battle_state, content_index)
    if int(_find_side_snapshot(post_snapshot, "P1").get("active_ultimate_points", -1)) != 0:
        return harness.fail_result("公开快照必须同步奥义释放后的清零状态")
    return harness.pass_result()

func _test_field_clash_high_mp_and_success_only_followup_contract(harness) -> Dictionary:
    var lose_payload = _build_gojo_vs_sukuna_state(harness, 2205)
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
    _run_turn(
        lose_core,
        lose_state,
        lose_content,
        _support.build_ultimate_command(lose_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _support.build_ultimate_command(lose_core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
    )
    if lose_state.field_state == null or lose_state.field_state.field_def_id != "sukuna_malevolent_shrine":
        return harness.fail_result("领域对拼时 MP 更高的一方必须保留领域")
    if int(lose_gojo.stat_stages.get("sp_attack", 0)) != 0:
        return harness.fail_result("Gojo 对拼失败时不应获得领域绑定增幅")
    if _has_rule_mod_apply_on_target(lose_core.battle_logger.event_log, lose_sukuna.unit_instance_id):
        return harness.fail_result("Gojo 对拼失败时不应再追加行动封锁")
    if not _find_field_clash_event(lose_core.battle_logger.event_log):
        return harness.fail_result("领域对拼结果必须写入日志")

    var win_payload = _build_gojo_vs_sukuna_state(harness, 2206)
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
    _run_turn(
        win_core,
        win_state,
        win_content,
        _support.build_ultimate_command(win_core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _support.build_ultimate_command(win_core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
    )
    if win_state.field_state == null or win_state.field_state.field_def_id != "gojo_unlimited_void_field":
        return harness.fail_result("领域对拼胜者应把自己的领域真正立住")
    if int(win_gojo.stat_stages.get("sp_attack", 0)) != 1:
        return harness.fail_result("Gojo 领域成功立住后应获得领域绑定增幅")
    if int(win_sukuna.stat_stages.get("attack", 0)) != 0 or int(win_sukuna.stat_stages.get("sp_attack", 0)) != 0:
        return harness.fail_result("旧领域被打断时其领域绑定 buff 必须一并消失")
    if not _has_rule_mod_apply_on_target(win_core.battle_logger.event_log, win_sukuna.unit_instance_id):
        return harness.fail_result("Gojo 只有在领域成功立住后才应追加行动封锁")
    return harness.pass_result()

func _test_field_clash_tie_replay_contract(harness) -> Dictionary:
    var first_result = _run_tied_domain_clash(harness, 2207)
    if first_result.has("error"):
        return harness.fail_result(str(first_result["error"]))
    var second_result = _run_tied_domain_clash(harness, 2207)
    if second_result.has("error"):
        return harness.fail_result(str(second_result["error"]))
    if first_result["field_id"] != second_result["field_id"]:
        return harness.fail_result("同 seed 的平 MP 领域对拼结果必须可复现")
    if abs(float(first_result["roll"]) - float(second_result["roll"])) > 0.000001:
        return harness.fail_result("同 seed 的平 MP 领域对拼随机值必须可复现")
    if String(first_result["summary"]) != String(second_result["summary"]):
        return harness.fail_result("领域对拼日志摘要必须和随机结果一起稳定复现")
    return harness.pass_result()

func _run_tied_domain_clash(harness, seed: int) -> Dictionary:
    var state_payload = _build_gojo_vs_sukuna_state(harness, seed)
    if state_payload.has("error"):
        return state_payload
    var core = state_payload["core"]
    var content_index = state_payload["content_index"]
    var battle_state = state_payload["battle_state"]
    var gojo_unit = battle_state.get_side("P1").get_active_unit()
    var sukuna_unit = battle_state.get_side("P2").get_active_unit()
    gojo_unit.current_mp = gojo_unit.max_mp
    gojo_unit.ultimate_points = gojo_unit.ultimate_points_cap
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    sukuna_unit.base_speed = 999
    core.battle_logger.reset()
    _run_turn(
        core,
        battle_state,
        content_index,
        _support.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
        _support.build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
    )
    var clash_event = _find_field_clash_event(core.battle_logger.event_log)
    if clash_event == null or clash_event.effect_roll == null:
        return {"error": "平 MP 领域对拼必须写出带随机值的 clash 日志"}
    return {
        "field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
        "roll": clash_event.effect_roll,
        "summary": clash_event.payload_summary,
    }

func _build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
    return _support.build_gojo_vs_sample_state(harness, seed)

func _build_gojo_vs_sukuna_state(harness, seed: int) -> Dictionary:
    return _support.build_gojo_battle_state(harness, seed, true, true)

func _run_turn(core, battle_state, content_index, p1_command, p2_command) -> void:
    core.turn_loop_controller.run_turn(battle_state, content_index, [p1_command, p2_command])

func _find_side_snapshot(public_snapshot: Dictionary, side_id: String) -> Dictionary:
    for side_snapshot in public_snapshot.get("sides", []):
        if str(side_snapshot.get("side_id", "")) == side_id:
            return side_snapshot
    return {}

func _has_ultimate_point_delta(event_log: Array, delta: int, after_value: int) -> bool:
    for log_event in event_log:
        if log_event.event_type != EventTypesScript.EFFECT_RESOURCE_MOD or log_event.value_changes.is_empty():
            continue
        var value_change = log_event.value_changes[0]
        if String(value_change.resource_name) == "ultimate_points" and int(value_change.delta) == delta and int(value_change.after_value) == after_value:
            return true
    return false

func _find_field_clash_event(event_log: Array):
    for log_event in event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_CLASH:
            return log_event
    return null

func _has_rule_mod_apply_on_target(event_log: Array, target_unit_id: String) -> bool:
    for log_event in event_log:
        if log_event.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and log_event.target_instance_id == target_unit_id:
            return true
    return false
