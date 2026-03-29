extends RefCounted
class_name ReplayTurnSuite

const ReplayInputScript := preload("res://src/battle_core/contracts/replay_input.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("deterministic_replay", failures, Callable(self, "_test_deterministic_replay").bind(harness))
    runner.run_test("replay_runs_to_end", failures, Callable(self, "_test_replay_runs_to_end").bind(harness))
    runner.run_test("timeout_wait_path", failures, Callable(self, "_test_timeout_wait_path").bind(harness))
    runner.run_test("resource_forced_default_path", failures, Callable(self, "_test_resource_forced_default_path").bind(harness))
    runner.run_test("wait_allowed_non_mp_blocked_path", failures, Callable(self, "_test_wait_allowed_non_mp_blocked_path").bind(harness))
    runner.run_test("manual_wait_no_damage_path", failures, Callable(self, "_test_manual_wait_no_damage_path").bind(harness))
    runner.run_test("sukuna_content_pack_smoke", failures, Callable(self, "_test_sukuna_content_pack_smoke").bind(harness))
    runner.run_test("on_matchup_changed_dedup_path", failures, Callable(self, "_test_on_matchup_changed_dedup_path").bind(harness))
    runner.run_test("miss_path", failures, Callable(self, "_test_miss_path").bind(harness))
    runner.run_test("field_expire_path", failures, Callable(self, "_test_field_expire_path").bind(harness))
    runner.run_test("init_chain_order", failures, Callable(self, "_test_init_chain_order").bind(harness))
    runner.run_test("battle_init_replacement_retriggers_matchup_changed", failures, Callable(self, "_test_battle_init_replacement_retriggers_matchup_changed").bind(harness))

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

func _test_timeout_wait_path(harness) -> Dictionary:
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
        if log_event.command_type == CommandTypesScript.WAIT \
        and log_event.command_source == "timeout_auto" \
        and log_event.event_type == EventTypesScript.ACTION_CAST:
            return harness.pass_result()
    return harness.fail_result("timeout wait cast event missing")

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

func _test_wait_allowed_non_mp_blocked_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(sample_factory.content_snapshot_paths())
    core.rng_service.reset(34)
    var battle_state = BattleStateScript.new()
    core.id_factory.reset()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = 34
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
    if core.rule_mod_service.create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_wait_non_mp_blocked", 0, p1_active.base_speed) == null:
        return harness.fail_result("failed to create legality deny rule_mod")
    var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not legal_action_set.wait_allowed:
        return harness.fail_result("wait should be allowed when non-mp blocked option exists")
    if not legal_action_set.forced_command_type.is_empty():
        return harness.fail_result("forced_command_type must be empty when wait is allowed")
    core.turn_loop_controller.run_turn(battle_state, content_index, [])
    for log_event in core.battle_logger.event_log:
        if log_event.command_type == CommandTypesScript.WAIT \
        and log_event.command_source == "timeout_auto" \
        and log_event.event_type == EventTypesScript.ACTION_CAST:
            return harness.pass_result()
    return harness.fail_result("timeout_auto should resolve to wait when non-mp block exists")

func _test_manual_wait_no_damage_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 35)
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
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
    var has_wait_cast: bool = false
    for log_event in core.battle_logger.event_log:
        if log_event.command_type == CommandTypesScript.WAIT and log_event.event_type == EventTypesScript.ACTION_CAST:
            has_wait_cast = true
            continue
        if log_event.command_type == CommandTypesScript.WAIT and log_event.event_type == EventTypesScript.EFFECT_DAMAGE:
            return harness.fail_result("wait should not deal damage or recoil")
        if log_event.command_type == CommandTypesScript.WAIT and log_event.event_type == EventTypesScript.ACTION_HIT:
            return harness.fail_result("wait should not enter hit/miss flow")
    if not has_wait_cast:
        return harness.fail_result("manual wait cast event missing")
    return harness.pass_result()

func _test_sukuna_content_pack_smoke(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_tidekit"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    core.rng_service.reset(36)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = 36
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, battle_setup)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    if p1_active == null:
        return harness.fail_result("missing P1 active unit for sukuna smoke")
    p1_active.current_mp = p1_active.max_mp
    p1_active.ultimate_points = p1_active.ultimate_points_cap
    core.battle_logger.reset()
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if battle_state.battle_result.finished:
        return harness.fail_result("sukuna smoke battle should continue")
    if battle_state.field_state == null or battle_state.field_state.field_def_id != "sukuna_malevolent_shrine":
        return harness.fail_result("sukuna ultimate should apply malevolent shrine field")
    if battle_state.field_state.remaining_turns != 2:
        return harness.fail_result("malevolent shrine should count current turn as turn 1 and tick to 2 remaining")
    var has_field_apply: bool = false
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_APPLY_FIELD and String(log_event.payload_summary).find("sukuna_malevolent_shrine") != -1:
            has_field_apply = true
    if not has_field_apply:
        return harness.fail_result("malevolent shrine apply event missing")
    return harness.pass_result()

func _test_on_matchup_changed_dedup_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var payload = ResourceModPayloadScript.new()
    payload.payload_type = "resource_mod"
    payload.resource_key = "mp"
    payload.amount = 1
    var effect = EffectDefinitionScript.new()
    effect.id = "test_matchup_changed_regen_effect"
    effect.display_name = "Matchup Changed Regen"
    effect.scope = "self"
    effect.trigger_names = PackedStringArray(["on_matchup_changed"])
    effect.payloads.clear()
    effect.payloads.append(payload)
    content_index.register_resource(effect)
    var passive = PassiveSkillDefinitionScript.new()
    passive.id = "test_matchup_changed_regen_passive"
    passive.display_name = "Matchup Changed Regen Passive"
    passive.trigger_names = PackedStringArray(["on_matchup_changed"])
    passive.effect_ids = PackedStringArray([effect.id])
    content_index.register_resource(passive)
    content_index.units["sample_pyron"].passive_skill_id = passive.id
    content_index.units["sample_tidekit"].passive_skill_id = passive.id
    content_index.units["sample_mossaur"].passive_skill_id = passive.id
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 37)
    var pre_turn_matchup_events: int = 0
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD \
        and ev.trigger_name == "on_matchup_changed" \
        and str(ev.source_instance_id).begins_with("passive_skill:"):
            pre_turn_matchup_events += 1
    if pre_turn_matchup_events != 2:
        return harness.fail_result("initial matchup_changed should trigger exactly once for each active unit")
    core.turn_loop_controller.run_turn(battle_state, content_index, [
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
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    var total_matchup_events: int = 0
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD \
        and ev.trigger_name == "on_matchup_changed" \
        and str(ev.source_instance_id).begins_with("passive_skill:"):
            total_matchup_events += 1
    if total_matchup_events != 4:
        return harness.fail_result("matchup_changed should trigger exactly once after the stable switch matchup")
    return harness.pass_result()

func _test_battle_init_replacement_retriggers_matchup_changed(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var matchup_payload = ResourceModPayloadScript.new()
    matchup_payload.payload_type = "resource_mod"
    matchup_payload.resource_key = "mp"
    matchup_payload.amount = 1
    var matchup_effect = EffectDefinitionScript.new()
    matchup_effect.id = "test_battle_init_matchup_changed_regen_effect"
    matchup_effect.display_name = "Battle Init Matchup Changed Regen"
    matchup_effect.scope = "self"
    matchup_effect.trigger_names = PackedStringArray(["on_matchup_changed"])
    matchup_effect.payloads.clear()
    matchup_effect.payloads.append(matchup_payload)
    content_index.register_resource(matchup_effect)

    var matchup_passive = PassiveSkillDefinitionScript.new()
    matchup_passive.id = "test_battle_init_matchup_changed_regen_passive"
    matchup_passive.display_name = "Battle Init Matchup Changed Regen Passive"
    matchup_passive.trigger_names = PackedStringArray(["on_matchup_changed"])
    matchup_passive.effect_ids = PackedStringArray([matchup_effect.id])
    content_index.register_resource(matchup_passive)
    content_index.units["sample_pyron"].passive_skill_id = matchup_passive.id
    content_index.units["sample_mossaur"].passive_skill_id = matchup_passive.id
    content_index.units["sample_tidekit"].passive_skill_id = matchup_passive.id

    var self_faint_payload = DamagePayloadScript.new()
    self_faint_payload.payload_type = "damage"
    self_faint_payload.amount = 999
    self_faint_payload.use_formula = false
    var self_faint_effect = EffectDefinitionScript.new()
    self_faint_effect.id = "test_battle_init_self_faint_effect"
    self_faint_effect.display_name = "Battle Init Self Faint"
    self_faint_effect.scope = "self"
    self_faint_effect.trigger_names = PackedStringArray(["battle_init"])
    self_faint_effect.payloads.clear()
    self_faint_effect.payloads.append(self_faint_payload)
    content_index.register_resource(self_faint_effect)

    var self_faint_item = PassiveItemDefinitionScript.new()
    self_faint_item.id = "test_battle_init_self_faint_item"
    self_faint_item.display_name = "Battle Init Self Faint Item"
    self_faint_item.trigger_names = PackedStringArray(["battle_init"])
    self_faint_item.effect_ids = PackedStringArray([self_faint_effect.id])
    content_index.register_resource(self_faint_item)
    content_index.units["sample_pyron"].passive_item_id = self_faint_item.id

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 43)
    var active_unit = battle_state.get_side("P1").get_active_unit()
    if active_unit == null or active_unit.public_id != "P1-B":
        return harness.fail_result("battle_init faint window should replace P1 active with bench unit before selection")

    var matchup_events: int = 0
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD \
        and ev.trigger_name == "on_matchup_changed" \
        and str(ev.source_instance_id).begins_with("passive_skill:"):
            matchup_events += 1
    if matchup_events != 4:
        return harness.fail_result("battle_init replacement should retrigger matchup_changed for the new stable matchup")
    return harness.pass_result()

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
            "skill_id": "sample_strike",
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
