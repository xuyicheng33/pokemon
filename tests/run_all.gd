extends SceneTree

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class TestReplacementSelector:
    extends "res://src/battle_core/lifecycle/replacement_selector.gd"

    var next_selection: Variant = null

    func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
        return next_selection

var _core_pool: Array = []

func _init() -> void:
    var failures: Array[String] = []
    _run_test("deterministic_replay", failures, _test_deterministic_replay)
    _run_test("replay_runs_to_end", failures, _test_replay_runs_to_end)
    _run_test("timeout_default_path", failures, _test_timeout_default_path)
    _run_test("resource_forced_default_path", failures, _test_resource_forced_default_path)
    _run_test("miss_path", failures, _test_miss_path)
    _run_test("field_expire_path", failures, _test_field_expire_path)
    _run_test("init_chain_order", failures, _test_init_chain_order)
    _run_test("turn_scope_active_and_field", failures, _test_turn_scope_active_and_field)
    _run_test("lifecycle_faint_replace_chain", failures, _test_lifecycle_faint_replace_chain)
    _run_test("manual_switch_lifecycle_chain", failures, _test_manual_switch_lifecycle_chain)
    _run_test("action_effects_on_kill_dispatch", failures, _test_action_effects_on_kill_dispatch)
    _run_test("invalid_command_payload_hard_failures", failures, _test_invalid_command_payload_hard_failures)
    _run_test("invalid_command_payload_out_of_legal_set", failures, _test_invalid_command_payload_out_of_legal_set)
    _run_test("replacement_selector_paths", failures, _test_replacement_selector_paths)
    _run_test("action_failed_post_start_target_missing", failures, _test_action_failed_post_start_target_missing)
    _run_test("invalid_chain_depth_max_guard", failures, _test_invalid_chain_depth_max_guard)
    _run_test("invalid_chain_depth_dedupe_guard", failures, _test_invalid_chain_depth_dedupe_guard)
    _run_test("invalid_state_corruption_guard", failures, _test_invalid_state_corruption_guard)
    _run_test("rule_mod_paths", failures, _test_rule_mod_paths)
    _run_test("rule_mod_field_scope_paths", failures, _test_rule_mod_field_scope_paths)
    _run_test("rule_mod_skill_legality_enforced", failures, _test_rule_mod_skill_legality_enforced)
    _run_test("invalid_battle_rule_mod_definition", failures, _test_invalid_battle_rule_mod_definition)
    _run_test("apply_effect_lifecycle_chain", failures, _test_apply_effect_lifecycle_chain)
    _run_test("content_validation_failures", failures, _test_content_validation_failures)
    _run_test("content_validation_new_constraints", failures, _test_content_validation_new_constraints)
    _run_test("apply_field_creator_non_action_chain", failures, _test_apply_field_creator_non_action_chain)
    _run_test("double_faint_reason_preserved", failures, _test_double_faint_reason_preserved)
    _run_test("battle_end_system_chain", failures, _test_battle_end_system_chain)
    _run_test("log_contract_semantics", failures, _test_log_contract_semantics)
    _dispose_core_pool()
    if failures.is_empty():
        print("ALL TESTS PASSED")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _run_test(test_name: String, failures: Array[String], test_callable: Callable) -> void:
    var result = test_callable.call()
    if typeof(result) != TYPE_DICTIONARY or not result.has("ok"):
        failures.append("%s: malformed test result" % test_name)
        return
    if bool(result["ok"]):
        print("PASS %s" % test_name)
        return
    failures.append("%s: %s" % [test_name, str(result.get("error", "unknown error"))])

func _pass() -> Dictionary:
    return {"ok": true}

func _fail(message: String) -> Dictionary:
    return {
        "ok": false,
        "error": message,
    }

func _build_core() -> Dictionary:
    var composer = BattleCoreComposerScript.new()
    if composer == null:
        return {"error": "BattleCoreComposer init failed"}
    var core = composer.compose()
    if core == null:
        return {"error": "compose returned null"}
    var required_services: Array[String] = [
        "command_builder",
        "replay_runner",
        "battle_initializer",
        "turn_loop_controller",
        "battle_logger",
        "id_factory",
        "rng_service",
    ]
    for service_name in required_services:
        if core.get(service_name) == null:
            return {"error": "missing core service: %s" % service_name}
    _core_pool.append(core)
    return {"core": core}

func _dispose_core_pool() -> void:
    for core in _core_pool:
        if core != null and core.has_method("dispose"):
            core.dispose()
    _core_pool.clear()

func _build_sample_factory():
    var sample_factory = SampleBattleFactoryScript.new()
    if sample_factory == null:
        return null
    return sample_factory

func _build_loaded_content_index(sample_factory):
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())
    return content_index

func _build_initialized_battle(core, content_index, sample_factory, seed: int):
    core.rng_service.reset(seed)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, sample_factory.build_sample_setup())
    return battle_state

func _test_deterministic_replay() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var replay_input = sample_factory.build_demo_replay_input(core.command_builder)
    if replay_input == null:
        return _fail("demo replay input build failed")
    var replay_output_a = core.replay_runner.run_replay(replay_input)
    var replay_output_b = core.replay_runner.run_replay(replay_input)
    if replay_output_a == null or replay_output_b == null:
        return _fail("replay output is null")
    if not replay_output_a.succeeded or not replay_output_b.succeeded:
        return _fail("replay runner returned failed status")
    if replay_output_a.final_state_hash.is_empty() or replay_output_b.final_state_hash.is_empty():
        return _fail("final_state_hash is empty")
    if replay_output_a.final_state_hash != replay_output_b.final_state_hash:
        return _fail("final_state_hash mismatch")
    if replay_output_a.event_log.size() != replay_output_b.event_log.size():
        return _fail("event_log size mismatch")
    return _pass()

func _test_replay_runs_to_end() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 15
    replay_input.content_snapshot_paths = sample_factory.content_snapshot_paths()
    replay_input.battle_setup = sample_factory.build_sample_setup()
    replay_input.command_stream = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    var replay_output = core.replay_runner.run_replay(replay_input)
    if replay_output == null or not replay_output.succeeded:
        return _fail("replay did not complete successfully")
    if replay_output.battle_result == null or not replay_output.battle_result.finished:
        return _fail("replay battle_result not finished")
    var has_battle_end: bool = false
    for ev in replay_output.event_log:
        if ev.event_type == EventTypesScript.RESULT_BATTLE_END:
            has_battle_end = true
            break
    if not has_battle_end:
        return _fail("result:battle_end event missing in replay")
    return _pass()

func _test_timeout_default_path() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 21
    replay_input.content_snapshot_paths = sample_factory.content_snapshot_paths()
    replay_input.battle_setup = sample_factory.build_sample_setup()
    replay_input.command_stream = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
    ]
    var replay_output = core.replay_runner.run_replay(replay_input)
    if replay_output == null:
        return _fail("replay output is null")
    for log_event in replay_output.event_log:
        if log_event.command_type == CommandTypesScript.TIMEOUT_DEFAULT and log_event.event_type == EventTypesScript.ACTION_CAST:
            return _pass()
    return _fail("timeout_default cast event missing")

func _test_resource_forced_default_path() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())
    core.rng_service.reset(33)
    var battle_state = BattleStateScript.new()
    core.id_factory.reset()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = 33
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, sample_factory.build_sample_setup())
    var p1 = battle_state.get_side("P1")
    if p1 == null:
        return _fail("side P1 missing after initialize")
    var p1_active = p1.get_active_unit()
    if p1_active == null:
        return _fail("P1 active unit missing after initialize")
    p1_active.current_mp = 0
    p1_active.regen_per_turn = 0
    for bench_unit_id in p1.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    var p2 = battle_state.get_side("P2")
    if p2 == null:
        return _fail("side P2 missing after initialize")
    var p2_active = p2.get_active_unit()
    if p2_active == null:
        return _fail("P2 active unit missing after initialize")
    p2_active.current_mp = 0
    p2_active.regen_per_turn = 0
    for bench_unit_id in p2.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    for log_event in core.battle_logger.event_log:
        if log_event.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT and log_event.event_type == EventTypesScript.ACTION_CAST:
            return _pass()
    return _fail("resource_forced_default cast event missing")

func _test_miss_path() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var replay_input = ReplayInputScript.new()
    replay_input.battle_seed = 5
    replay_input.content_snapshot_paths = sample_factory.content_snapshot_paths()
    replay_input.battle_setup = sample_factory.build_sample_setup()
    replay_input.command_stream = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_whiff",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    var replay_output = core.replay_runner.run_replay(replay_input)
    if replay_output == null:
        return _fail("replay output is null")
    for log_event in replay_output.event_log:
        if log_event.event_type == EventTypesScript.ACTION_MISS:
            return _pass()
    return _fail("miss event missing")

func _test_field_expire_path() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var replay_output = core.replay_runner.run_replay(sample_factory.build_demo_replay_input(core.command_builder))
    if replay_output == null:
        return _fail("replay output is null")
    if replay_output.final_battle_state.field_state != null:
        return _fail("field_state should expire after turn 2")
    for log_event in replay_output.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
            return _pass()
    return _fail("field expire event missing")

func _test_init_chain_order() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var enter_payload = StatModPayloadScript.new()
    enter_payload.payload_type = "stat_mod"
    enter_payload.stat_name = "attack"
    enter_payload.stage_delta = 1
    var enter_effect = EffectDefinitionScript.new()
    enter_effect.id = "test_enter_stat_mod"
    enter_effect.display_name = "Test Enter Stat Mod"
    enter_effect.scope = "self"
    enter_effect.trigger_names = PackedStringArray(["on_enter"])
    enter_effect.payloads.clear()
    enter_effect.payloads.append(enter_payload)
    var enter_passive = PassiveSkillDefinitionScript.new()
    enter_passive.id = "test_passive_on_enter"
    enter_passive.display_name = "Test Passive On Enter"
    enter_passive.trigger_names = PackedStringArray(["on_enter"])
    enter_passive.effect_ids = PackedStringArray([enter_effect.id])
    content_index.register_resource(enter_effect)
    content_index.register_resource(enter_passive)

    var init_payload = ResourceModPayloadScript.new()
    init_payload.payload_type = "resource_mod"
    init_payload.resource_key = "mp"
    init_payload.amount = 3
    var init_effect = EffectDefinitionScript.new()
    init_effect.id = "test_battle_init_mp_mod"
    init_effect.display_name = "Test Battle Init MP Mod"
    init_effect.scope = "self"
    init_effect.trigger_names = PackedStringArray(["battle_init"])
    init_effect.payloads.clear()
    init_effect.payloads.append(init_payload)
    var init_item = PassiveItemDefinitionScript.new()
    init_item.id = "test_item_on_battle_init"
    init_item.display_name = "Test Item On Battle Init"
    init_item.trigger_names = PackedStringArray(["battle_init"])
    init_item.effect_ids = PackedStringArray([init_effect.id])
    content_index.register_resource(init_effect)
    content_index.register_resource(init_item)

    content_index.units["sample_pyron"].passive_skill_id = enter_passive.id
    content_index.units["sample_pyron"].passive_item_id = init_item.id

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 101)
    if battle_state.battle_result.finished:
        return _fail("battle finished during initialization")

    var enter_effect_idx := -1
    var battle_init_idx := -1
    var init_effect_idx := -1
    for i in range(core.battle_logger.event_log.size()):
        var ev = core.battle_logger.event_log[i]
        if enter_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
            enter_effect_idx = i
        if battle_init_idx == -1 and ev.event_type == EventTypesScript.SYSTEM_BATTLE_INIT:
            battle_init_idx = i
        if init_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD and str(ev.source_instance_id).begins_with("passive_item:"):
            init_effect_idx = i
    if enter_effect_idx == -1 or battle_init_idx == -1 or init_effect_idx == -1:
        return _fail("missing init-chain events")
    if not (enter_effect_idx < battle_init_idx and battle_init_idx < init_effect_idx):
        return _fail("on_enter -> battle_init ordering mismatch")
    return _pass()

func _test_turn_scope_active_and_field() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var turn_payload = StatModPayloadScript.new()
    turn_payload.payload_type = "stat_mod"
    turn_payload.stat_name = "speed"
    turn_payload.stage_delta = 1
    var turn_effect = EffectDefinitionScript.new()
    turn_effect.id = "test_turn_start_stat_mod"
    turn_effect.display_name = "Test Turn Start Stat Mod"
    turn_effect.scope = "self"
    turn_effect.trigger_names = PackedStringArray(["turn_start"])
    turn_effect.payloads.clear()
    turn_effect.payloads.append(turn_payload)
    var turn_passive = PassiveSkillDefinitionScript.new()
    turn_passive.id = "test_passive_turn_start"
    turn_passive.display_name = "Test Passive Turn Start"
    turn_passive.trigger_names = PackedStringArray(["turn_start"])
    turn_passive.effect_ids = PackedStringArray([turn_effect.id])
    content_index.register_resource(turn_effect)
    content_index.register_resource(turn_passive)
    content_index.units["sample_pyron"].passive_skill_id = turn_passive.id
    content_index.units["sample_mossaur"].passive_skill_id = turn_passive.id
    content_index.units["sample_tidekit"].passive_skill_id = turn_passive.id

    var field_payload = ResourceModPayloadScript.new()
    field_payload.payload_type = "resource_mod"
    field_payload.resource_key = "mp"
    field_payload.amount = 2
    var field_effect = EffectDefinitionScript.new()
    field_effect.id = "test_field_turn_start_effect"
    field_effect.display_name = "Test Field Turn Start Effect"
    field_effect.scope = "self"
    field_effect.trigger_names = PackedStringArray(["turn_start"])
    field_effect.payloads.clear()
    field_effect.payloads.append(field_payload)
    var field_def = FieldDefinitionScript.new()
    field_def.id = "test_turn_scope_field"
    field_def.display_name = "Turn Scope Field"
    field_def.effect_ids = PackedStringArray([field_effect.id])
    content_index.register_resource(field_effect)
    content_index.register_resource(field_def)

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 102)
    var bench_ids: Array = []
    for side_state in battle_state.sides:
        for bench_unit_id in side_state.bench_order:
            bench_ids.append(bench_unit_id)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    p1_active.current_mp = 10
    p1_active.regen_per_turn = 0
    var field_state = FieldStateScript.new()
    field_state.field_def_id = field_def.id
    field_state.instance_id = "test_field_instance"
    field_state.creator = p1_active.unit_instance_id
    field_state.remaining_turns = 2
    field_state.source_kind_order = 1
    field_state.source_order_speed_snapshot = p1_active.base_speed
    battle_state.field_state = field_state

    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    var passive_event_count: int = 0
    var field_event_count: int = 0
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
            passive_event_count += 1
            if bench_ids.has(ev.target_instance_id):
                return _fail("bench unit triggered turn_start passive")
        if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD and ev.source_instance_id == "test_field_instance":
            field_event_count += 1
    if passive_event_count != 2:
        return _fail("turn_start passive should trigger exactly for active units")
    if field_event_count < 1:
        return _fail("field turn_start effect missing")
    return _pass()

func _test_lifecycle_faint_replace_chain() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var kill_payload = StatModPayloadScript.new()
    kill_payload.payload_type = "stat_mod"
    kill_payload.stat_name = "attack"
    kill_payload.stage_delta = 1
    var kill_effect = EffectDefinitionScript.new()
    kill_effect.id = "test_on_kill_buff_effect"
    kill_effect.display_name = "On Kill Buff"
    kill_effect.scope = "self"
    kill_effect.trigger_names = PackedStringArray(["on_kill"])
    kill_effect.payloads.clear()
    kill_effect.payloads.append(kill_payload)
    var kill_passive = PassiveSkillDefinitionScript.new()
    kill_passive.id = "test_on_kill_passive"
    kill_passive.display_name = "On Kill Passive"
    kill_passive.trigger_names = PackedStringArray(["on_kill"])
    kill_passive.effect_ids = PackedStringArray([kill_effect.id])
    content_index.register_resource(kill_effect)
    content_index.register_resource(kill_passive)
    content_index.units["sample_pyron"].passive_skill_id = kill_passive.id

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 103)
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p2_active.current_hp = 1
    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)

    var faint_idx := -1
    var kill_effect_idx := -1
    var exit_idx := -1
    var replace_idx := -1
    var enter_idx := -1
    for i in range(core.battle_logger.event_log.size()):
        var ev = core.battle_logger.event_log[i]
        if faint_idx == -1 and ev.event_type == EventTypesScript.STATE_FAINT:
            faint_idx = i
        if kill_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
            kill_effect_idx = i
        if exit_idx == -1 and ev.event_type == EventTypesScript.STATE_EXIT:
            exit_idx = i
        if replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE:
            replace_idx = i
        if ev.event_type == EventTypesScript.STATE_ENTER and i > replace_idx and replace_idx != -1:
            enter_idx = i
            break
    if faint_idx == -1 or exit_idx == -1 or replace_idx == -1 or enter_idx == -1:
        return _fail("missing lifecycle events in faint window")
    if kill_effect_idx == -1:
        return _fail("on_kill trigger effect missing")
    if not (faint_idx < kill_effect_idx and kill_effect_idx < exit_idx and exit_idx < replace_idx and replace_idx < enter_idx):
        return _fail("faint lifecycle ordering mismatch")
    return _pass()

func _test_manual_switch_lifecycle_chain() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var switch_payload = StatModPayloadScript.new()
    switch_payload.payload_type = "stat_mod"
    switch_payload.stat_name = "attack"
    switch_payload.stage_delta = 1
    var switch_effect = EffectDefinitionScript.new()
    switch_effect.id = "test_manual_switch_on_switch_effect"
    switch_effect.display_name = "Manual Switch On Switch"
    switch_effect.scope = "self"
    switch_effect.trigger_names = PackedStringArray(["on_switch"])
    switch_effect.payloads.clear()
    switch_effect.payloads.append(switch_payload)
    var switch_passive = PassiveSkillDefinitionScript.new()
    switch_passive.id = "test_manual_switch_on_switch_passive"
    switch_passive.display_name = "Manual Switch On Switch Passive"
    switch_passive.trigger_names = PackedStringArray(["on_switch"])
    switch_passive.effect_ids = PackedStringArray([switch_effect.id])
    content_index.register_resource(switch_effect)
    content_index.register_resource(switch_passive)

    var exit_payload = StatModPayloadScript.new()
    exit_payload.payload_type = "stat_mod"
    exit_payload.stat_name = "defense"
    exit_payload.stage_delta = 1
    var exit_effect = EffectDefinitionScript.new()
    exit_effect.id = "test_manual_switch_on_exit_effect"
    exit_effect.display_name = "Manual Switch On Exit"
    exit_effect.scope = "self"
    exit_effect.trigger_names = PackedStringArray(["on_exit"])
    exit_effect.payloads.clear()
    exit_effect.payloads.append(exit_payload)
    var exit_item = PassiveItemDefinitionScript.new()
    exit_item.id = "test_manual_switch_on_exit_item"
    exit_item.display_name = "Manual Switch On Exit Item"
    exit_item.trigger_names = PackedStringArray(["on_exit"])
    exit_item.effect_ids = PackedStringArray([exit_effect.id])
    content_index.register_resource(exit_effect)
    content_index.register_resource(exit_item)

    var enter_payload = StatModPayloadScript.new()
    enter_payload.payload_type = "stat_mod"
    enter_payload.stat_name = "speed"
    enter_payload.stage_delta = 1
    var enter_effect = EffectDefinitionScript.new()
    enter_effect.id = "test_manual_switch_on_enter_effect"
    enter_effect.display_name = "Manual Switch On Enter"
    enter_effect.scope = "self"
    enter_effect.trigger_names = PackedStringArray(["on_enter"])
    enter_effect.payloads.clear()
    enter_effect.payloads.append(enter_payload)
    var enter_passive = PassiveSkillDefinitionScript.new()
    enter_passive.id = "test_manual_switch_on_enter_passive"
    enter_passive.display_name = "Manual Switch On Enter Passive"
    enter_passive.trigger_names = PackedStringArray(["on_enter"])
    enter_passive.effect_ids = PackedStringArray([enter_effect.id])
    content_index.register_resource(enter_effect)
    content_index.register_resource(enter_passive)

    content_index.units["sample_pyron"].passive_skill_id = switch_passive.id
    content_index.units["sample_pyron"].passive_item_id = exit_item.id
    content_index.units["sample_mossaur"].passive_skill_id = enter_passive.id

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 108)
    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "target_public_id": "P1-B",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)

    var switch_idx := -1
    var on_switch_effect_idx := -1
    var on_exit_effect_idx := -1
    var state_exit_idx := -1
    var state_enter_idx := -1
    var on_enter_effect_idx := -1
    for i in range(core.battle_logger.event_log.size()):
        var ev = core.battle_logger.event_log[i]
        if switch_idx == -1 and ev.event_type == EventTypesScript.STATE_SWITCH:
            switch_idx = i
        if on_switch_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
            on_switch_effect_idx = i
        if on_exit_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_item:"):
            on_exit_effect_idx = i
        if state_exit_idx == -1 and ev.event_type == EventTypesScript.STATE_EXIT:
            state_exit_idx = i
        if state_enter_idx == -1 and ev.event_type == EventTypesScript.STATE_ENTER and ev.target_instance_id == battle_state.get_unit_by_public_id("P1-B").unit_instance_id:
            state_enter_idx = i
        if on_enter_effect_idx == -1 and state_enter_idx != -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:") and i > state_enter_idx:
            on_enter_effect_idx = i
    if switch_idx == -1 or on_switch_effect_idx == -1 or on_exit_effect_idx == -1 or state_exit_idx == -1 or state_enter_idx == -1 or on_enter_effect_idx == -1:
        return _fail("missing manual switch lifecycle events")
    if not (switch_idx < on_switch_effect_idx and on_switch_effect_idx < on_exit_effect_idx and on_exit_effect_idx < state_exit_idx and state_exit_idx < state_enter_idx and state_enter_idx < on_enter_effect_idx):
        return _fail("manual switch lifecycle ordering mismatch (%d,%d,%d,%d,%d,%d)" % [switch_idx, on_switch_effect_idx, on_exit_effect_idx, state_exit_idx, state_enter_idx, on_enter_effect_idx])
    return _pass()

func _test_action_effects_on_kill_dispatch() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var kill_effect_payload = StatModPayloadScript.new()
    kill_effect_payload.payload_type = "stat_mod"
    kill_effect_payload.stat_name = "attack"
    kill_effect_payload.stage_delta = 1
    var kill_effect = EffectDefinitionScript.new()
    kill_effect.id = "test_action_kill_effect"
    kill_effect.display_name = "Action Kill Effect"
    kill_effect.scope = "self"
    kill_effect.trigger_names = PackedStringArray(["on_kill"])
    kill_effect.payloads.clear()
    kill_effect.payloads.append(kill_effect_payload)
    content_index.register_resource(kill_effect)

    var kill_skill = SkillDefinitionScript.new()
    kill_skill.id = "test_action_kill_skill"
    kill_skill.display_name = "Action Kill Skill"
    kill_skill.damage_kind = "physical"
    kill_skill.power = 40
    kill_skill.accuracy = 100
    kill_skill.mp_cost = 0
    kill_skill.priority = 0
    kill_skill.targeting = "enemy_active_slot"
    kill_skill.effects_on_kill_ids = PackedStringArray([kill_effect.id])
    content_index.register_resource(kill_skill)
    if not content_index.units["sample_pyron"].skill_ids.has(kill_skill.id):
        content_index.units["sample_pyron"].skill_ids.append(kill_skill.id)

    var kill_state = _build_initialized_battle(core, content_index, sample_factory, 109)
    var kill_p1_active = kill_state.get_side("P1").get_active_unit()
    kill_p1_active.base_speed = 999
    var kill_p2_active = kill_state.get_side("P2").get_active_unit()
    kill_p2_active.current_hp = 1
    core.turn_loop_controller.run_turn(kill_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": kill_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    var has_kill_effect_log: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.target_instance_id == kill_p1_active.unit_instance_id and str(ev.source_instance_id).begins_with("action_"):
            has_kill_effect_log = true
            break
    if not has_kill_effect_log:
        return _fail("effects_on_kill did not trigger on kill")

    var non_kill_state = _build_initialized_battle(core, content_index, sample_factory, 110)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(non_kill_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": kill_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("action_"):
            return _fail("effects_on_kill should not trigger without kill")
    return _pass()

func _test_invalid_command_payload_hard_failures() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var unknown_side_state = _build_initialized_battle(core, content_index, sample_factory, 111)
    core.turn_loop_controller.run_turn(unknown_side_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P3",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
    ])
    if not unknown_side_state.battle_result.finished or unknown_side_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return _fail("unknown side command should fail-fast with invalid_command_payload")

    var duplicate_state = _build_initialized_battle(core, content_index, sample_factory, 112)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(duplicate_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "target_public_id": "P1-B",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    if not duplicate_state.battle_result.finished or duplicate_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return _fail("duplicate submit should fail-fast with invalid_command_payload")

    var non_participant_state = _build_initialized_battle(core, content_index, sample_factory, 113)
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(non_participant_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-B",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    if not non_participant_state.battle_result.finished or non_participant_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return _fail("non-participant actor should fail-fast with invalid_command_payload")
    return _pass()

func _test_invalid_command_payload_out_of_legal_set() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 214)

    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_ultimate_burst",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ])
    if not battle_state.battle_result.finished:
        return _fail("illegal skill submit should end battle in selection phase")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return _fail("expected invalid_command_payload, got %s" % str(battle_state.battle_result.reason))
    return _pass()

func _test_replacement_selector_paths() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var legal_state = _build_initialized_battle(core, content_index, sample_factory, 215)
    var legal_side = legal_state.get_side("P1")
    if legal_side == null or legal_side.bench_order.size() < 2:
        return _fail("expected at least 2 legal bench candidates for replacement selector test")
    var legal_selector := TestReplacementSelector.new()
    var chosen_unit_id: String = legal_side.bench_order[1]
    legal_selector.next_selection = chosen_unit_id
    core.replacement_service.replacement_selector = legal_selector
    var legal_result: Dictionary = core.replacement_service.resolve_replacement(legal_state, legal_side, "forced_replace")
    if legal_result.get("invalid_code", null) != null:
        return _fail("legal replacement selection should pass")
    var entered_unit = legal_result.get("entered_unit", null)
    if entered_unit == null or entered_unit.unit_instance_id != chosen_unit_id:
        return _fail("replacement selector did not pick requested legal target")

    var invalid_state = _build_initialized_battle(core, content_index, sample_factory, 216)
    var invalid_side = invalid_state.get_side("P1")
    var invalid_selector := TestReplacementSelector.new()
    invalid_selector.next_selection = "unit_not_in_bench"
    core.replacement_service.replacement_selector = invalid_selector
    var invalid_result: Dictionary = core.replacement_service.resolve_replacement(invalid_state, invalid_side, "forced_replace")
    if invalid_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
        return _fail("invalid replacement target should fail-fast with invalid_replacement_selection")

    var empty_state = _build_initialized_battle(core, content_index, sample_factory, 217)
    var empty_side = empty_state.get_side("P1")
    var empty_selector := TestReplacementSelector.new()
    empty_selector.next_selection = null
    core.replacement_service.replacement_selector = empty_selector
    var empty_result: Dictionary = core.replacement_service.resolve_replacement(empty_state, empty_side, "faint")
    if empty_result.get("invalid_code", null) != ErrorCodesScript.INVALID_REPLACEMENT_SELECTION:
        return _fail("empty replacement selection should fail-fast with invalid_replacement_selection")

    return _pass()

func _test_action_failed_post_start_target_missing() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 114)

    var actor = battle_state.get_unit_by_public_id("P1-A")
    if actor == null:
        return _fail("missing P1-A actor")
    var command = core.command_builder.build_command({
        "turn_index": 1,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": "P1",
        "actor_id": actor.unit_instance_id,
        "skill_id": "sample_strike",
    })
    var queued_action = core.action_queue_builder.build_queue([command], battle_state, content_index)[0]
    var p2_side = battle_state.get_side("P2")
    p2_side.clear_active_unit()

    var action_result = core.action_executor.execute_action(queued_action, battle_state, content_index)
    if action_result.invalid_battle_code != null:
        return _fail("target missing at execution start should not raise invalid_battle")
    if action_result.result_type != "action_failed_post_start":
        return _fail("expected action_failed_post_start when target slot missing, got %s" % str(action_result.result_type))
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.ACTION_FAILED_POST_START:
            return _pass()
    return _fail("missing action_failed_post_start log event")

func _test_invalid_chain_depth_max_guard() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 118)

    var depth_guard_payload = StatModPayloadScript.new()
    depth_guard_payload.payload_type = "stat_mod"
    depth_guard_payload.stat_name = "attack"
    depth_guard_payload.stage_delta = 1
    var depth_guard_effect = EffectDefinitionScript.new()
    depth_guard_effect.id = "test_depth_guard_effect"
    depth_guard_effect.display_name = "Depth Guard Effect"
    depth_guard_effect.scope = "self"
    depth_guard_effect.trigger_names = PackedStringArray(["on_cast"])
    depth_guard_effect.payloads.clear()
    depth_guard_effect.payloads.append(depth_guard_payload)
    content_index.register_resource(depth_guard_effect)

    var p1_active = battle_state.get_side("P1").get_active_unit()
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = "test_depth_chain"
    chain_context.chain_origin = "action"
    chain_context.command_type = CommandTypesScript.SKILL
    chain_context.command_source = "manual"
    chain_context.actor_id = p1_active.unit_instance_id
    chain_context.chain_depth = battle_state.max_chain_depth
    battle_state.chain_context = chain_context
    var effect_events = core.trigger_dispatcher.collect_events(
        "on_cast",
        battle_state,
        content_index,
        PackedStringArray([depth_guard_effect.id]),
        p1_active.unit_instance_id,
        "action_depth_guard",
        2,
        p1_active.base_speed,
        battle_state.chain_context
    )
    if effect_events.is_empty():
        return _fail("failed to build depth guard effect event")
    core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
    if core.payload_executor.last_invalid_battle_code != ErrorCodesScript.INVALID_CHAIN_DEPTH:
        return _fail("expected invalid_chain_depth on max depth guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
    return _pass()

func _test_invalid_chain_depth_dedupe_guard() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 119)

    var dedupe_effect = EffectDefinitionScript.new()
    dedupe_effect.id = "test_dedupe_guard_effect"
    dedupe_effect.display_name = "Dedupe Guard Effect"
    dedupe_effect.scope = "self"
    dedupe_effect.trigger_names = PackedStringArray(["on_cast"])
    dedupe_effect.payloads.clear()
    content_index.register_resource(dedupe_effect)

    var p1_active = battle_state.get_side("P1").get_active_unit()
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = "test_dedupe_chain"
    chain_context.chain_origin = "action"
    chain_context.command_type = CommandTypesScript.SKILL
    chain_context.command_source = "manual"
    chain_context.actor_id = p1_active.unit_instance_id
    chain_context.step_counter = 7
    battle_state.chain_context = chain_context
    var effect_events = core.trigger_dispatcher.collect_events(
        "on_cast",
        battle_state,
        content_index,
        PackedStringArray([dedupe_effect.id]),
        p1_active.unit_instance_id,
        "action_dedupe_guard",
        2,
        p1_active.base_speed,
        battle_state.chain_context
    )
    if effect_events.is_empty():
        return _fail("failed to build dedupe guard effect event")
    core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
    if core.payload_executor.last_invalid_battle_code != null:
        return _fail("first dedupe event should pass")
    battle_state.chain_context.step_counter = 7
    core.payload_executor.execute_effect_event(effect_events[0], battle_state, content_index)
    if core.payload_executor.last_invalid_battle_code != ErrorCodesScript.INVALID_CHAIN_DEPTH:
        return _fail("expected invalid_chain_depth on dedupe guard, got %s" % str(core.payload_executor.last_invalid_battle_code))
    return _pass()

func _test_invalid_state_corruption_guard() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 120)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    p1_active.current_hp = p1_active.max_hp + 1
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if not battle_state.battle_result.finished:
        return _fail("state corruption should fail-fast")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_STATE_CORRUPTION:
        return _fail("expected invalid_state_corruption, got %s" % str(battle_state.battle_result.reason))
    return _pass()

func _test_rule_mod_paths() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 104)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p1_before_mp: int = p1_active.current_mp

    var deny_payload = RuleModPayloadScript.new()
    deny_payload.payload_type = "rule_mod"
    deny_payload.mod_kind = "skill_legality"
    deny_payload.mod_op = "deny"
    deny_payload.value = "sample_strike"
    deny_payload.scope = "self"
    deny_payload.duration_mode = "turns"
    deny_payload.duration = 2
    deny_payload.decrement_on = "turn_start"
    deny_payload.stacking = "replace"
    deny_payload.priority = 10
    if core.rule_mod_service.create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_deny", 0, p1_active.base_speed) == null:
        return _fail("failed to create skill_legality rule_mod")

    var regen_payload = RuleModPayloadScript.new()
    regen_payload.payload_type = "rule_mod"
    regen_payload.mod_kind = "mp_regen"
    regen_payload.mod_op = "set"
    regen_payload.value = 0
    regen_payload.scope = "self"
    regen_payload.duration_mode = "turns"
    regen_payload.duration = 1
    regen_payload.decrement_on = "turn_start"
    regen_payload.stacking = "replace"
    regen_payload.priority = 10
    if core.rule_mod_service.create_instance(regen_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_regen", 0, p1_active.base_speed) == null:
        return _fail("failed to create mp_regen rule_mod")

    var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if legal_action_set.legal_skill_ids.has("sample_strike"):
        return _fail("skill_legality rule_mod did not block sample_strike")

    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if p1_active.current_mp != p1_before_mp:
        return _fail("mp_regen rule_mod did not override turn_start regen")
    var has_remove_log: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == p1_active.unit_instance_id:
            has_remove_log = true
            break
    if not has_remove_log:
        return _fail("rule_mod remove event missing")

    var baseline_state = _build_initialized_battle(core, content_index, sample_factory, 105)
    var modded_state = _build_initialized_battle(core, content_index, sample_factory, 105)
    var baseline_commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(baseline_state, content_index, baseline_commands)
    var baseline_damage = _extract_damage_from_log(core.battle_logger.event_log, "P1-A")

    var final_mod_payload = RuleModPayloadScript.new()
    final_mod_payload.payload_type = "rule_mod"
    final_mod_payload.mod_kind = "final_mod"
    final_mod_payload.mod_op = "mul"
    final_mod_payload.value = 2.0
    final_mod_payload.scope = "self"
    final_mod_payload.duration_mode = "turns"
    final_mod_payload.duration = 2
    final_mod_payload.decrement_on = "turn_end"
    final_mod_payload.stacking = "replace"
    final_mod_payload.priority = 10
    var modded_p1_active = modded_state.get_side("P1").get_active_unit()
    if core.rule_mod_service.create_instance(final_mod_payload, {"scope": "unit", "id": modded_p1_active.unit_instance_id}, modded_state, "test_rule_mod_final", 0, modded_p1_active.base_speed) == null:
        return _fail("failed to create final_mod rule_mod")
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(modded_state, content_index, baseline_commands)
    var modded_damage = _extract_damage_from_log(core.battle_logger.event_log, "P1-A")
    if baseline_damage <= 0 or modded_damage <= baseline_damage:
        return _fail("final_mod rule_mod did not increase damage")
    return _pass()

func _test_rule_mod_field_scope_paths() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 115)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p1_active.regen_per_turn = 0
    p2_active.regen_per_turn = 0
    p1_active.current_mp = 0
    p2_active.current_mp = 0

    var field_regen_payload = RuleModPayloadScript.new()
    field_regen_payload.payload_type = "rule_mod"
    field_regen_payload.mod_kind = "mp_regen"
    field_regen_payload.mod_op = "add"
    field_regen_payload.value = 5
    field_regen_payload.scope = "field"
    field_regen_payload.duration_mode = "turns"
    field_regen_payload.duration = 1
    field_regen_payload.decrement_on = "turn_start"
    field_regen_payload.stacking = "replace"
    field_regen_payload.priority = 5
    if core.rule_mod_service.create_instance(field_regen_payload, {"scope": "field", "id": "field"}, battle_state, "test_field_regen_mod", 0, 0) == null:
        return _fail("failed to create field-scope mp_regen rule_mod")
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if p1_active.current_mp != 5 or p2_active.current_mp != 5:
        return _fail("field-scope mp_regen rule_mod did not apply to both active units")
    var has_field_remove_log: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == "field":
            has_field_remove_log = true
            break
    if not has_field_remove_log:
        return _fail("field-scope rule_mod remove event missing")

    var baseline_state = _build_initialized_battle(core, content_index, sample_factory, 116)
    var modded_state = _build_initialized_battle(core, content_index, sample_factory, 116)
    var baseline_commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(baseline_state, content_index, baseline_commands)
    var baseline_damage = _extract_damage_from_log(core.battle_logger.event_log, "P1-A")
    var field_final_mod_payload = RuleModPayloadScript.new()
    field_final_mod_payload.payload_type = "rule_mod"
    field_final_mod_payload.mod_kind = "final_mod"
    field_final_mod_payload.mod_op = "mul"
    field_final_mod_payload.value = 2.0
    field_final_mod_payload.scope = "field"
    field_final_mod_payload.duration_mode = "turns"
    field_final_mod_payload.duration = 2
    field_final_mod_payload.decrement_on = "turn_end"
    field_final_mod_payload.stacking = "replace"
    field_final_mod_payload.priority = 10
    if core.rule_mod_service.create_instance(field_final_mod_payload, {"scope": "field", "id": "field"}, modded_state, "test_field_final_mod", 0, 0) == null:
        return _fail("failed to create field-scope final_mod rule_mod")
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(modded_state, content_index, baseline_commands)
    var modded_damage = _extract_damage_from_log(core.battle_logger.event_log, "P1-A")
    if baseline_damage <= 0 or modded_damage <= baseline_damage:
        return _fail("field-scope final_mod rule_mod did not increase damage")

    var legality_state = _build_initialized_battle(core, content_index, sample_factory, 117)
    var field_legality_payload = RuleModPayloadScript.new()
    field_legality_payload.payload_type = "rule_mod"
    field_legality_payload.mod_kind = "skill_legality"
    field_legality_payload.mod_op = "deny"
    field_legality_payload.value = "sample_strike"
    field_legality_payload.scope = "field"
    field_legality_payload.duration_mode = "turns"
    field_legality_payload.duration = 2
    field_legality_payload.decrement_on = "turn_start"
    field_legality_payload.stacking = "replace"
    field_legality_payload.priority = 10
    if core.rule_mod_service.create_instance(field_legality_payload, {"scope": "field", "id": "field"}, legality_state, "test_field_skill_legality", 0, 0) == null:
        return _fail("failed to create field-scope skill_legality rule_mod")
    var legal_action_set = core.legal_action_service.get_legal_actions(legality_state, "P1", content_index)
    if legal_action_set.legal_skill_ids.has("sample_strike"):
        return _fail("field-scope skill_legality rule_mod did not block sample_strike")

    var invalid_scope_payload = RuleModPayloadScript.new()
    invalid_scope_payload.payload_type = "rule_mod"
    invalid_scope_payload.mod_kind = "final_mod"
    invalid_scope_payload.mod_op = "mul"
    invalid_scope_payload.value = 1.1
    invalid_scope_payload.scope = "field"
    invalid_scope_payload.duration_mode = "turns"
    invalid_scope_payload.duration = 1
    invalid_scope_payload.decrement_on = "turn_start"
    invalid_scope_payload.stacking = "replace"
    var invalid_owner = legality_state.get_side("P1").get_active_unit()
    if core.rule_mod_service.create_instance(invalid_scope_payload, {"scope": "unit", "id": invalid_owner.unit_instance_id}, legality_state, "test_invalid_field_owner", 0, invalid_owner.base_speed) != null:
        return _fail("invalid field owner binding should fail")
    if core.rule_mod_service.last_error_code != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
        return _fail("invalid field owner binding should return invalid_rule_mod_definition")
    return _pass()

func _test_invalid_battle_rule_mod_definition() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var invalid_payload = RuleModPayloadScript.new()
    invalid_payload.payload_type = "rule_mod"
    invalid_payload.mod_kind = "final_mod"
    invalid_payload.mod_op = "mul"
    invalid_payload.value = 1.5
    invalid_payload.scope = "self"
    invalid_payload.duration_mode = "turns"
    invalid_payload.duration = 1
    invalid_payload.decrement_on = ""
    invalid_payload.stacking = "replace"
    var invalid_effect = EffectDefinitionScript.new()
    invalid_effect.id = "test_invalid_rule_mod_effect"
    invalid_effect.display_name = "Invalid Rule Mod Effect"
    invalid_effect.scope = "self"
    invalid_effect.trigger_names = PackedStringArray(["on_cast"])
    invalid_effect.payloads.clear()
    invalid_effect.payloads.append(invalid_payload)
    var invalid_skill = SkillDefinitionScript.new()
    invalid_skill.id = "test_invalid_rule_mod_skill"
    invalid_skill.display_name = "Invalid Rule Mod Skill"
    invalid_skill.damage_kind = "none"
    invalid_skill.power = 0
    invalid_skill.accuracy = 100
    invalid_skill.mp_cost = 0
    invalid_skill.priority = 0
    invalid_skill.targeting = "self"
    invalid_skill.effects_on_cast_ids = PackedStringArray([invalid_effect.id])
    content_index.register_resource(invalid_effect)
    content_index.register_resource(invalid_skill)
    var p1_def = content_index.units["sample_pyron"]
    if not p1_def.skill_ids.has(invalid_skill.id):
        p1_def.skill_ids.append(invalid_skill.id)

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 106)
    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": invalid_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)
    if not battle_state.battle_result.finished:
        return _fail("invalid_battle should finish battle immediately")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
        return _fail("invalid_battle reason mismatch: %s" % str(battle_state.battle_result.reason))
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
            return _pass()
    return _fail("invalid_battle log event missing")

func _test_rule_mod_skill_legality_enforced() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 107)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    if p1_active == null:
        return _fail("P1 active unit missing")

    var deny_payload = RuleModPayloadScript.new()
    deny_payload.payload_type = "rule_mod"
    deny_payload.mod_kind = "skill_legality"
    deny_payload.mod_op = "deny"
    deny_payload.value = "sample_strike"
    deny_payload.scope = "self"
    deny_payload.duration_mode = "turns"
    deny_payload.duration = 2
    deny_payload.decrement_on = "turn_start"
    deny_payload.stacking = "replace"
    deny_payload.priority = 10
    if core.rule_mod_service.create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_skill_legality_gate", 0, p1_active.base_speed) == null:
        return _fail("failed to create skill_legality deny instance")

    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_strike",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_strike",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)
    if not battle_state.battle_result.finished:
        return _fail("illegal manual command should fail-fast")
    if battle_state.battle_result.reason != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
        return _fail("expected invalid_command_payload, got %s" % str(battle_state.battle_result.reason))
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.SYSTEM_INVALID_BATTLE and ev.invalid_battle_code == ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
            return _pass()
    return _fail("missing invalid_battle log for illegal command")

func _test_log_contract_semantics() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var replay_output = core.replay_runner.run_replay(sample_factory.build_demo_replay_input(core.command_builder))
    if replay_output == null:
        return _fail("replay output is null")

    var system_turn_start_event = null
    var action_cast_event = null
    var effect_damage_event = null
    for ev in replay_output.event_log:
        if system_turn_start_event == null and ev.event_type == EventTypesScript.SYSTEM_TURN_START:
            system_turn_start_event = ev
        if action_cast_event == null and ev.event_type == EventTypesScript.ACTION_CAST and ev.command_source == "manual":
            action_cast_event = ev
        if effect_damage_event == null and ev.event_type == EventTypesScript.EFFECT_DAMAGE:
            effect_damage_event = ev
    if system_turn_start_event == null or action_cast_event == null:
        return _fail("missing system/action events for log contract checks")
    if effect_damage_event == null:
        return _fail("missing effect event for log contract checks")
    if system_turn_start_event.log_schema_version != 2 or action_cast_event.log_schema_version != 2:
        return _fail("log_schema_version should be 2 for all events")
    if system_turn_start_event.chain_origin != "turn_start":
        return _fail("system event chain_origin mismatch")
    if action_cast_event.chain_origin != "action":
        return _fail("action event chain_origin mismatch")
    if system_turn_start_event.action_id != null or system_turn_start_event.action_queue_index != null or system_turn_start_event.actor_id != null:
        return _fail("system event action fields must be null")
    if system_turn_start_event.command_type != EventTypesScript.SYSTEM_TURN_START or system_turn_start_event.command_source != "system":
        return _fail("system event command fields mismatch")
    if system_turn_start_event.select_timeout != null:
        return _fail("system event select_timeout must be null")
    if action_cast_event.action_id == null or action_cast_event.actor_id == null:
        return _fail("action event should inherit root action fields")
    if action_cast_event.command_source != "manual":
        return _fail("action event command_source should be manual")
    if action_cast_event.select_timeout != false:
        return _fail("manual action chain select_timeout should be false")
    if effect_damage_event.trigger_name == null or effect_damage_event.cause_event_id == null:
        return _fail("effect event should include trigger_name and cause_event_id")
    return _pass()

func _test_apply_effect_lifecycle_chain() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var dot_payload = DamagePayloadScript.new()
    dot_payload.payload_type = "dot"
    dot_payload.amount = 5
    dot_payload.use_formula = false
    var dot_effect = EffectDefinitionScript.new()
    dot_effect.id = "test_dot_tick"
    dot_effect.display_name = "Dot Tick"
    dot_effect.scope = "self"
    dot_effect.duration_mode = "turns"
    dot_effect.duration = 1
    dot_effect.decrement_on = "turn_end"
    dot_effect.stacking = "replace"
    dot_effect.priority = 0
    dot_effect.trigger_names = PackedStringArray(["turn_end"])
    dot_effect.payloads.clear()
    dot_effect.payloads.append(dot_payload)
    content_index.register_resource(dot_effect)

    var apply_payload = ApplyEffectPayloadScript.new()
    apply_payload.payload_type = "apply_effect"
    apply_payload.effect_definition_id = dot_effect.id
    var apply_effect = EffectDefinitionScript.new()
    apply_effect.id = "test_apply_dot"
    apply_effect.display_name = "Apply Dot"
    apply_effect.scope = "target"
    apply_effect.duration_mode = "permanent"
    apply_effect.trigger_names = PackedStringArray(["on_cast"])
    apply_effect.payloads.clear()
    apply_effect.payloads.append(apply_payload)
    content_index.register_resource(apply_effect)

    var dot_skill = SkillDefinitionScript.new()
    dot_skill.id = "test_dot_skill"
    dot_skill.display_name = "Dot Skill"
    dot_skill.damage_kind = "none"
    dot_skill.power = 0
    dot_skill.accuracy = 100
    dot_skill.mp_cost = 0
    dot_skill.priority = 0
    dot_skill.targeting = "enemy_active_slot"
    dot_skill.effects_on_cast_ids = PackedStringArray([apply_effect.id])
    content_index.register_resource(dot_skill)
    if not content_index.units["sample_pyron"].skill_ids.has(dot_skill.id):
        content_index.units["sample_pyron"].skill_ids.append(dot_skill.id)

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 211)
    var p2_active = battle_state.get_side("P2").get_active_unit()
    p2_active.current_hp = min(p2_active.max_hp, max(20, p2_active.current_hp))
    var commands: Array = [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": dot_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ]
    core.turn_loop_controller.run_turn(battle_state, content_index, commands)

    var has_apply: bool = false
    var has_tick: bool = false
    var has_remove: bool = false
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_APPLY_EFFECT and String(ev.payload_summary).find(dot_effect.id) != -1:
            has_apply = true
        if ev.event_type == EventTypesScript.EFFECT_DAMAGE and ev.trigger_name == "turn_end" and String(ev.payload_summary).find("dot") != -1:
            has_tick = true
        if ev.event_type == EventTypesScript.EFFECT_REMOVE_EFFECT and String(ev.payload_summary).find("effect expired: %s" % dot_effect.id) != -1:
            has_remove = true
    if not has_apply or not has_tick or not has_remove:
        return _fail("apply_effect lifecycle events missing")
    return _pass()

func _test_content_validation_failures() -> Dictionary:
    var content_index = BattleContentIndexScript.new()

    var bad_skill = SkillDefinitionScript.new()
    bad_skill.id = "bad_skill"
    bad_skill.display_name = "Bad Skill"
    bad_skill.targeting = "bad_target"
    bad_skill.priority = 9
    content_index.register_resource(bad_skill)

    var bad_unit = UnitDefinitionScript.new()
    bad_unit.id = "bad_unit"
    bad_unit.display_name = "Bad Unit"
    bad_unit.skill_ids = PackedStringArray(["missing_skill"])
    bad_unit.ultimate_skill_id = "missing_ultimate"
    content_index.register_resource(bad_unit)

    var bad_rule_mod = RuleModPayloadScript.new()
    bad_rule_mod.payload_type = "rule_mod"
    bad_rule_mod.mod_kind = "bad_kind"
    bad_rule_mod.mod_op = "bad_op"
    bad_rule_mod.scope = "self"
    bad_rule_mod.duration_mode = "turns"
    bad_rule_mod.duration = 1
    bad_rule_mod.decrement_on = "turn_start"
    bad_rule_mod.stacking = "none"
    bad_rule_mod.priority = 0
    var bad_effect = EffectDefinitionScript.new()
    bad_effect.id = "bad_effect"
    bad_effect.display_name = "Bad Effect"
    bad_effect.scope = "self"
    bad_effect.duration_mode = "permanent"
    bad_effect.trigger_names = PackedStringArray(["on_cast"])
    bad_effect.payloads.clear()
    bad_effect.payloads.append(bad_rule_mod)
    content_index.register_resource(bad_effect)

    var errors: Array = content_index.validate_snapshot()
    if errors.is_empty():
        return _fail("content validator did not report failures")
    var has_priority_error: bool = false
    var has_rule_mod_error: bool = false
    var has_missing_ref: bool = false
    for error_msg in errors:
        var msg = str(error_msg)
        if msg.find("priority out of range") != -1:
            has_priority_error = true
        if msg.find("rule_mod invalid") != -1:
            has_rule_mod_error = true
        if msg.find("missing skill") != -1:
            has_missing_ref = true
    if not (has_priority_error and has_rule_mod_error and has_missing_ref):
        return _fail("content validation errors missing expected categories")
    return _pass()

func _test_content_validation_new_constraints() -> Dictionary:
    var content_index = BattleContentIndexScript.new()

    var regular_ok = SkillDefinitionScript.new()
    regular_ok.id = "regular_ok"
    regular_ok.display_name = "Regular OK"
    regular_ok.targeting = "enemy_active"
    regular_ok.priority = 0
    content_index.register_resource(regular_ok)

    var regular_bad = SkillDefinitionScript.new()
    regular_bad.id = "regular_bad_priority"
    regular_bad.display_name = "Regular Bad Priority"
    regular_bad.targeting = "enemy_active"
    regular_bad.priority = 5
    content_index.register_resource(regular_bad)

    var ultimate_bad = SkillDefinitionScript.new()
    ultimate_bad.id = "ultimate_bad_priority"
    ultimate_bad.display_name = "Ultimate Bad Priority"
    ultimate_bad.targeting = "enemy_active"
    ultimate_bad.priority = 0
    content_index.register_resource(ultimate_bad)

    var slot_bad_unit = UnitDefinitionScript.new()
    slot_bad_unit.id = "slot_bad_unit"
    slot_bad_unit.display_name = "Slot Bad Unit"
    slot_bad_unit.skill_ids = PackedStringArray(["regular_ok", "regular_bad_priority"])
    slot_bad_unit.ultimate_skill_id = "ultimate_bad_priority"
    content_index.register_resource(slot_bad_unit)

    var regular_priority_bad_unit = UnitDefinitionScript.new()
    regular_priority_bad_unit.id = "regular_priority_bad_unit"
    regular_priority_bad_unit.display_name = "Regular Priority Bad Unit"
    regular_priority_bad_unit.skill_ids = PackedStringArray(["regular_bad_priority", "regular_ok", "regular_ok"])
    regular_priority_bad_unit.ultimate_skill_id = ""
    content_index.register_resource(regular_priority_bad_unit)

    var ultimate_duplicate_unit = UnitDefinitionScript.new()
    ultimate_duplicate_unit.id = "ultimate_duplicate_unit"
    ultimate_duplicate_unit.display_name = "Ultimate Duplicate Unit"
    ultimate_duplicate_unit.skill_ids = PackedStringArray(["ultimate_bad_priority", "regular_ok", "regular_ok"])
    ultimate_duplicate_unit.ultimate_skill_id = "ultimate_bad_priority"
    content_index.register_resource(ultimate_duplicate_unit)

    var snapshot_errors: Array = content_index.validate_snapshot()
    if snapshot_errors.is_empty():
        return _fail("new content constraints should report validation failures")

    var has_regular_priority_error: bool = false
    var has_ultimate_priority_error: bool = false
    var has_slot_error: bool = false
    var has_ultimate_in_regular_error: bool = false
    for error_msg in snapshot_errors:
        var msg = str(error_msg)
        if msg.find("used in unit.skill_ids must have priority in -2..2") != -1:
            has_regular_priority_error = true
        if msg.find("used as ultimate must have priority +5 or -5") != -1:
            has_ultimate_priority_error = true
        if msg.find("skill_ids must contain exactly 3 entries") != -1:
            has_slot_error = true
        if msg.find("used as ultimate must not appear in any unit.skill_ids") != -1:
            has_ultimate_in_regular_error = true
    if not (has_regular_priority_error and has_ultimate_priority_error and has_slot_error and has_ultimate_in_regular_error):
        return _fail("new content validation constraints missing expected failures")

    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var runtime_content = _build_loaded_content_index(sample_factory)
    var duplicate_item = PassiveItemDefinitionScript.new()
    duplicate_item.id = "duplicate_item_for_setup_validation"
    duplicate_item.display_name = "Duplicate Item"
    runtime_content.register_resource(duplicate_item)
    runtime_content.units["sample_pyron"].passive_item_id = duplicate_item.id
    runtime_content.units["sample_mossaur"].passive_item_id = duplicate_item.id
    var battle_setup = sample_factory.build_sample_setup()
    var setup_errors: Array = runtime_content.validate_setup(battle_setup)
    var has_duplicate_item_error: bool = false
    for error_msg in setup_errors:
        if str(error_msg).find("duplicated passive_item_id") != -1:
            has_duplicate_item_error = true
            break
    if not has_duplicate_item_error:
        return _fail("battle setup should reject duplicate passive items on same side")
    return _pass()

func _test_apply_field_creator_non_action_chain() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)

    var field_def = FieldDefinitionScript.new()
    field_def.id = "test_non_action_field"
    field_def.display_name = "Non Action Field"
    field_def.effect_ids = PackedStringArray()
    content_index.register_resource(field_def)

    var apply_field_payload = ApplyFieldPayloadScript.new()
    apply_field_payload.payload_type = "apply_field"
    apply_field_payload.field_definition_id = field_def.id
    var apply_field_effect = EffectDefinitionScript.new()
    apply_field_effect.id = "test_non_action_apply_field_effect"
    apply_field_effect.display_name = "Non Action Apply Field"
    apply_field_effect.scope = "self"
    apply_field_effect.trigger_names = PackedStringArray(["on_enter"])
    apply_field_effect.duration_mode = "turns"
    apply_field_effect.duration = 2
    apply_field_effect.payloads.clear()
    apply_field_effect.payloads.append(apply_field_payload)
    content_index.register_resource(apply_field_effect)

    var apply_field_passive = PassiveSkillDefinitionScript.new()
    apply_field_passive.id = "test_non_action_apply_field_passive"
    apply_field_passive.display_name = "Non Action Apply Field Passive"
    apply_field_passive.trigger_names = PackedStringArray(["on_enter"])
    apply_field_passive.effect_ids = PackedStringArray([apply_field_effect.id])
    content_index.register_resource(apply_field_passive)
    content_index.units["sample_pyron"].passive_skill_id = apply_field_passive.id

    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 218)
    if battle_state.field_state == null:
        return _fail("on_enter apply_field should create field_state")
    var p1_active = battle_state.get_side("P1").get_active_unit()
    if p1_active == null:
        return _fail("missing P1 active unit")
    if battle_state.field_state.creator != p1_active.unit_instance_id:
        return _fail("field creator should use effect owner in non-action chain")
    if battle_state.field_state.source_instance_id.is_empty():
        return _fail("field source_instance_id should not be empty")
    return _pass()

func _test_double_faint_reason_preserved() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var content_index = _build_loaded_content_index(sample_factory)
    var battle_state = _build_initialized_battle(core, content_index, sample_factory, 219)
    for side_state in battle_state.sides:
        for unit_state in side_state.team_units:
            unit_state.current_hp = 0
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    if not battle_state.battle_result.finished:
        return _fail("battle should finish when both sides have no available units")
    if battle_state.battle_result.result_type != "draw":
        return _fail("double faint should end in draw")
    if battle_state.battle_result.reason != "double_faint":
        return _fail("double faint reason should remain double_faint, got %s" % str(battle_state.battle_result.reason))
    return _pass()

func _test_battle_end_system_chain() -> Dictionary:
    var core_payload = _build_core()
    if core_payload.has("error"):
        return _fail(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = _build_sample_factory()
    if sample_factory == null:
        return _fail("SampleBattleFactory init failed")
    var replay_output = core.replay_runner.run_replay(sample_factory.build_demo_replay_input(core.command_builder))
    if replay_output == null:
        return _fail("replay output is null")
    var has_battle_end: bool = false
    for ev in replay_output.event_log:
        if ev.event_type != EventTypesScript.RESULT_BATTLE_END:
            continue
        has_battle_end = true
        if String(ev.command_type) == EventTypesScript.RESULT_BATTLE_END:
            return _fail("battle_end command_type should not be result:battle_end")
        if not String(ev.command_type).begins_with("system:"):
            return _fail("battle_end command_type should be system:*")
        if String(ev.command_source) != "system":
            return _fail("battle_end command_source should be system")
        if ev.chain_origin == "action":
            return _fail("battle_end chain_origin should not be action")
    if not has_battle_end:
        return _fail("battle_end event missing in replay log")
    return _pass()

func _extract_damage_from_log(event_log: Array, attacker_public_id: String) -> int:
    for ev in event_log:
        if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
            continue
        if not String(ev.payload_summary).begins_with("%s dealt" % attacker_public_id):
            continue
        if ev.value_changes.is_empty():
            continue
        return abs(int(ev.value_changes[0].delta))
    return -1
