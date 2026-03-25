extends SceneTree

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const SampleBattleFactoryScript := preload("res://src/composition/sample_battle_factory.gd")
const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func _init() -> void:
    var failures: Array[String] = []
    _run_test("deterministic_replay", failures, _test_deterministic_replay)
    _run_test("timeout_default_path", failures, _test_timeout_default_path)
    _run_test("resource_forced_default_path", failures, _test_resource_forced_default_path)
    _run_test("miss_path", failures, _test_miss_path)
    _run_test("field_expire_path", failures, _test_field_expire_path)
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
    return {"core": core}

func _build_sample_factory():
    var sample_factory = SampleBattleFactoryScript.new()
    if sample_factory == null:
        return null
    return sample_factory

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
