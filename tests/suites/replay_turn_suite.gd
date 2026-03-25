extends RefCounted
class_name ReplayTurnSuite

const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("deterministic_replay", failures, Callable(self, "_test_deterministic_replay").bind(harness))
    runner.run_test("replay_runs_to_end", failures, Callable(self, "_test_replay_runs_to_end").bind(harness))
    runner.run_test("timeout_default_path", failures, Callable(self, "_test_timeout_default_path").bind(harness))
    runner.run_test("resource_forced_default_path", failures, Callable(self, "_test_resource_forced_default_path").bind(harness))
    runner.run_test("miss_path", failures, Callable(self, "_test_miss_path").bind(harness))
    runner.run_test("field_expire_path", failures, Callable(self, "_test_field_expire_path").bind(harness))
    runner.run_test("init_chain_order", failures, Callable(self, "_test_init_chain_order").bind(harness))

func _test_deterministic_replay(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var replay_input = sample_factory.build_demo_replay_input(core.command_builder)
    if replay_input == null:
        return harness.fail_result("demo replay input build failed")
    var replay_output_a = core.replay_runner.run_replay(replay_input)
    var replay_output_b = core.replay_runner.run_replay(replay_input)
    if replay_output_a == null or replay_output_b == null:
        return harness.fail_result("replay output is null")
    if not replay_output_a.succeeded or not replay_output_b.succeeded:
        return harness.fail_result("replay runner returned failed status")
    if replay_output_a.final_state_hash.is_empty() or replay_output_b.final_state_hash.is_empty():
        return harness.fail_result("final_state_hash is empty")
    if replay_output_a.final_state_hash != replay_output_b.final_state_hash:
        return harness.fail_result("final_state_hash mismatch")
    if replay_output_a.event_log.size() != replay_output_b.event_log.size():
        return harness.fail_result("event_log size mismatch")
    return harness.pass_result()

func _test_replay_runs_to_end(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
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
        return harness.fail_result("replay did not complete successfully")
    if replay_output.battle_result == null or not replay_output.battle_result.finished:
        return harness.fail_result("replay battle_result not finished")
    var has_battle_end: bool = false
    for ev in replay_output.event_log:
        if ev.event_type == EventTypesScript.RESULT_BATTLE_END:
            has_battle_end = true
            break
    if not has_battle_end:
        return harness.fail_result("result:battle_end event missing in replay")
    return harness.pass_result()

func _test_timeout_default_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
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
        return harness.fail_result("replay output is null")
    for log_event in replay_output.event_log:
        if log_event.command_type == CommandTypesScript.TIMEOUT_DEFAULT and log_event.event_type == EventTypesScript.ACTION_CAST:
            return harness.pass_result()
    return harness.fail_result("timeout_default cast event missing")

func _test_resource_forced_default_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
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
        return harness.fail_result("side P1 missing after initialize")
    var p1_active = p1.get_active_unit()
    if p1_active == null:
        return harness.fail_result("P1 active unit missing after initialize")
    p1_active.current_mp = 0
    p1_active.regen_per_turn = 0
    for bench_unit_id in p1.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    var p2 = battle_state.get_side("P2")
    if p2 == null:
        return harness.fail_result("side P2 missing after initialize")
    var p2_active = p2.get_active_unit()
    if p2_active == null:
        return harness.fail_result("P2 active unit missing after initialize")
    p2_active.current_mp = 0
    p2_active.regen_per_turn = 0
    for bench_unit_id in p2.bench_order:
        var bench_unit = battle_state.get_unit(bench_unit_id)
        if bench_unit != null:
            bench_unit.current_hp = 0
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    for log_event in core.battle_logger.event_log:
        if log_event.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT and log_event.event_type == EventTypesScript.ACTION_CAST:
            return harness.pass_result()
    return harness.fail_result("resource_forced_default cast event missing")

func _test_miss_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
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
        return harness.fail_result("replay output is null")
    for log_event in replay_output.event_log:
        if log_event.event_type == EventTypesScript.ACTION_MISS:
            return harness.pass_result()
    return harness.fail_result("miss event missing")

func _test_field_expire_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var replay_output = core.replay_runner.run_replay(sample_factory.build_demo_replay_input(core.command_builder))
    if replay_output == null:
        return harness.fail_result("replay output is null")
    if replay_output.final_battle_state.field_state != null:
        return harness.fail_result("field_state should expire after turn 2")
    for log_event in replay_output.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
            return harness.pass_result()
    return harness.fail_result("field expire event missing")

func _test_init_chain_order(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

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

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 101)
    if battle_state.battle_result.finished:
        return harness.fail_result("battle finished during initialization")

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
        return harness.fail_result("missing init-chain events")
    if not (enter_effect_idx < battle_init_idx and battle_init_idx < init_effect_idx):
        return harness.fail_result("on_enter -> battle_init ordering mismatch")
    return harness.pass_result()
