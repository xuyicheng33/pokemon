extends RefCounted
class_name SukunaKamadoSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

var _support = SukunaTestSupportScript.new()

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("sukuna_kamado_stack_on_exit_path", failures, Callable(self, "_test_sukuna_kamado_stack_on_exit_path").bind(harness))
    runner.run_test("sukuna_kamado_natural_expire_path", failures, Callable(self, "_test_sukuna_kamado_natural_expire_path").bind(harness))
    runner.run_test("sukuna_kamado_stack_cap_path", failures, Callable(self, "_test_sukuna_kamado_stack_cap_path").bind(harness))
    runner.run_test("sukuna_kamado_forced_replace_on_exit_path", failures, Callable(self, "_test_sukuna_kamado_forced_replace_on_exit_path").bind(harness))

func _test_sukuna_kamado_stack_on_exit_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hiraku"].accuracy = 100
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 703)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for kamado stack test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 2, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    var kamado_instances: Array = []
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            kamado_instances.append(effect_instance)
    if kamado_instances.size() != 2:
        return harness.fail_result("double hiraku should leave exactly two kamado stacks before exit")
    target_unit.current_hp = target_unit.max_hp
    var hp_before_exit: int = target_unit.current_hp
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 3, "P1", "P1-A"),
        _build_manual_switch_command(core, 3, "P2", "P2-A", "P2-B"),
    ])
    var on_exit_damage_events: int = 0
    for log_event in core.service("battle_logger").event_log:
        if log_event.event_type == EventTypesScript.EFFECT_DAMAGE \
        and log_event.trigger_name == "on_exit" \
        and log_event.target_instance_id == target_unit.unit_instance_id:
            on_exit_damage_events += 1
    var expected_on_exit_damage := _calc_expected_fixed_effect_damage(core, content_index, "sukuna_kamado_mark", target_unit) * 2
    if hp_before_exit - target_unit.current_hp != expected_on_exit_damage:
        return harness.fail_result("double kamado on_exit damage mismatch: delta=%d expected=%d events=%d" % [
            hp_before_exit - target_unit.current_hp,
            expected_on_exit_damage,
            on_exit_damage_events,
        ])
    if on_exit_damage_events != 2:
        return harness.fail_result("double kamado should emit two on_exit damage events")
    return harness.pass_result()

func _test_sukuna_kamado_natural_expire_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hiraku"].accuracy = 100
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 706)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for kamado expire test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var kamado_stack_count: int = 0
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            kamado_stack_count += 1
    if kamado_stack_count != 1:
        return harness.fail_result("single hiraku should leave exactly one kamado stack before natural expire")
    target_unit.current_hp = target_unit.max_hp
    var hp_before_expire: int = target_unit.current_hp
    core.service("battle_logger").reset()
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 2, "P1", "P1-A"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 3, "P1", "P1-A"),
        _build_manual_wait_command(core, 3, "P2", "P2-A"),
    ])
    var on_expire_damage_events: int = 0
    for log_event in core.service("battle_logger").event_log:
        if log_event.event_type == EventTypesScript.EFFECT_DAMAGE \
        and log_event.trigger_name == "on_expire" \
        and log_event.target_instance_id == target_unit.unit_instance_id:
            on_expire_damage_events += 1
    var expected_on_expire_damage := _calc_expected_fixed_effect_damage(core, content_index, "sukuna_kamado_explode", target_unit)
    if hp_before_expire - target_unit.current_hp != expected_on_expire_damage:
        return harness.fail_result("kamado natural expire damage mismatch: delta=%d expected=%d events=%d" % [
            hp_before_expire - target_unit.current_hp,
            expected_on_expire_damage,
            on_expire_damage_events,
        ])
    if on_expire_damage_events != 1:
        return harness.fail_result("single kamado natural expire should emit exactly one on_expire damage event")
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            return harness.fail_result("kamado stack should be removed after natural expire")
    return harness.pass_result()

func _test_sukuna_kamado_stack_cap_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 707)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    var kamado_definition = content_index.effects.get("sukuna_kamado_mark", null)
    if sukuna_unit == null or target_unit == null or kamado_definition == null:
        return harness.fail_result("kamado stack cap test missing runtime or content state")
    var before_ids: Array[String] = []
    var before_remaining: Array[int] = []
    for stack_index in range(3):
        var created_instance = core.service("effect_instance_service").create_instance(
            kamado_definition,
            target_unit.unit_instance_id,
            battle_state,
            "test_kamado_stack_%d" % stack_index,
            1,
            sukuna_unit.base_speed
        )
        if created_instance == null:
            return harness.fail_result("kamado stack cap test failed to create baseline stack %d" % stack_index)
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            before_ids.append(effect_instance.instance_id)
            before_remaining.append(int(effect_instance.remaining))
    before_ids.sort()
    before_remaining.sort()
    var overflow_instance = core.service("effect_instance_service").create_instance(
        kamado_definition,
        target_unit.unit_instance_id,
        battle_state,
        "test_kamado_stack_overflow",
        1,
        sukuna_unit.base_speed
    )
    if overflow_instance == null:
        return harness.fail_result("kamado overflow apply should be ignored, not fail")
    if not core.service("effect_instance_service").last_apply_skipped:
        return harness.fail_result("kamado overflow apply should be marked as skipped once max_stacks is reached")
    var after_ids: Array[String] = []
    var after_remaining: Array[int] = []
    for effect_instance in target_unit.effect_instances:
        if effect_instance.def_id == "sukuna_kamado_mark":
            after_ids.append(effect_instance.instance_id)
            after_remaining.append(int(effect_instance.remaining))
    after_ids.sort()
    after_remaining.sort()
    if after_ids.size() != 3:
        return harness.fail_result("kamado max_stacks should clamp to exactly three instances")
    if after_ids != before_ids:
        return harness.fail_result("kamado overflow apply should not replace existing stacks")
    if after_remaining != before_remaining:
        return harness.fail_result("kamado overflow apply should not refresh existing stack durations")
    return harness.pass_result()

func _test_sukuna_kamado_forced_replace_on_exit_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hiraku"].accuracy = 100
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 708)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for forced_replace kamado test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var hp_before_forced_replace: int = target_unit.current_hp
    battle_state.chain_context = core.service("battle_result_service").build_system_chain("system:replace")
    var replace_result: Dictionary = core.service("replacement_service").execute_forced_replace(
        battle_state,
        content_index,
        target_unit.unit_instance_id,
        "forced_replace",
        Callable(core.service("trigger_batch_runner"), "execute_trigger_batch")
    )
    if replace_result.get("invalid_code", null) != null:
        return harness.fail_result("forced_replace should not fail after kamado apply")
    if not bool(replace_result.get("replaced", false)):
        return harness.fail_result("forced_replace should replace kamado target with a bench unit")
    var forced_replace_on_exit_events: int = 0
    for log_event in core.service("battle_logger").event_log:
        if log_event.event_type == EventTypesScript.EFFECT_DAMAGE \
        and log_event.trigger_name == "on_exit" \
        and log_event.target_instance_id == target_unit.unit_instance_id:
            forced_replace_on_exit_events += 1
    var expected_forced_replace_damage := _calc_expected_fixed_effect_damage(core, content_index, "sukuna_kamado_mark", target_unit)
    if hp_before_forced_replace - target_unit.current_hp != expected_forced_replace_damage:
        return harness.fail_result("forced_replace kamado on_exit damage mismatch: delta=%d expected=%d" % [
            hp_before_forced_replace - target_unit.current_hp,
            expected_forced_replace_damage,
        ])
    if forced_replace_on_exit_events != 1:
        return harness.fail_result("forced_replace should emit exactly one kamado on_exit damage event")
    return harness.pass_result()

func _build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
    return _support.build_sukuna_setup(sample_factory, p1_regular_skill_overrides)

func _build_battle_state(core, content_index, battle_setup, seed: int):
    return _support.build_battle_state(core, content_index, battle_setup, seed)

func _build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return _support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return _support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func _build_manual_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
    return _support.build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func _calc_expected_fixed_effect_damage(core, content_index, effect_id: String, target_unit) -> int:
    return _support.calc_expected_fixed_effect_damage(core, content_index, effect_id, target_unit)
