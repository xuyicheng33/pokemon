extends RefCounted
class_name SukunaSuite

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("sukuna_default_loadout_contract", failures, Callable(self, "_test_sukuna_default_loadout_contract").bind(harness))
    runner.run_test("sukuna_matchup_regen_runtime_path", failures, Callable(self, "_test_sukuna_matchup_regen_runtime_path").bind(harness))
    runner.run_test("sukuna_reverse_ritual_heal_path", failures, Callable(self, "_test_sukuna_reverse_ritual_heal_path").bind(harness))
    runner.run_test("sukuna_kamado_stack_on_exit_path", failures, Callable(self, "_test_sukuna_kamado_stack_on_exit_path").bind(harness))
    runner.run_test("sukuna_domain_expire_chain_path", failures, Callable(self, "_test_sukuna_domain_expire_chain_path").bind(harness))
    runner.run_test("sukuna_domain_break_chain_path", failures, Callable(self, "_test_sukuna_domain_break_chain_path").bind(harness))
    runner.run_test("sukuna_field_accuracy_override_path", failures, Callable(self, "_test_sukuna_field_accuracy_override_path").bind(harness))

func _test_sukuna_default_loadout_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var sukuna = content_index.units.get("sukuna", null)
    if sukuna == null:
        return harness.fail_result("missing sukuna unit definition")
    if sukuna.skill_ids != PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku"]):
        return harness.fail_result("sukuna default loadout must stay fixed as 解/捌/开")
    if sukuna.skill_ids.has("sukuna_reverse_ritual"):
        return harness.fail_result("sukuna_reverse_ritual should stay in candidate pool, not default loadout")
    if sukuna.candidate_skill_ids != PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_hiraku", "sukuna_reverse_ritual"]):
        return harness.fail_result("sukuna candidate skill pool should be structured as 解/捌/开/反转术式")
    if sukuna.ultimate_skill_id != "sukuna_fukuma_mizushi":
        return harness.fail_result("sukuna ultimate should stay fixed as 伏魔御厨子")
    if sukuna.passive_skill_id != "sukuna_teach_love":
        return harness.fail_result("sukuna passive should stay fixed as 教会你爱的是...")
    if not content_index.skills.has("sukuna_reverse_ritual"):
        return harness.fail_result("sukuna candidate skill pool should retain 反转术式 for replacement tests")
    return harness.pass_result()

func _test_sukuna_matchup_regen_runtime_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 701)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    if sukuna_unit == null:
        return harness.fail_result("missing sukuna active unit")
    var regen_instances: Array = []
    for instance in sukuna_unit.rule_mod_instances:
        if instance.mod_kind == "mp_regen":
            regen_instances.append(instance)
    if regen_instances.size() != 1:
        return harness.fail_result("sukuna should receive exactly one matchup regen rule_mod on init")
    var expected_value := _resolve_matchup_gap_value(
        _sum_unit_bst(sukuna_unit),
        _sum_unit_bst(battle_state.get_side("P2").get_active_unit()),
        PackedInt32Array([20, 40, 70, 110, 160]),
        PackedInt32Array([5, 4, 3, 2, 1]),
        0
    )
    if int(regen_instances[0].value) != expected_value:
        return harness.fail_result("sukuna matchup regen rule_mod value mismatch")
    var regen_payload = content_index.effects["sukuna_refresh_love_regen"].payloads[0]
    if int(regen_payload.value) != 0:
        return harness.fail_result("runtime formula must not mutate shared rule_mod payload value")
    return harness.pass_result()

func _test_sukuna_reverse_ritual_heal_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var ritual_loadout := PackedStringArray(["sukuna_kai", "sukuna_hatsu", "sukuna_reverse_ritual"])
    var battle_setup = _build_sukuna_setup(sample_factory, {0: ritual_loadout})
    var battle_state = _build_battle_state(core, content_index, battle_setup, 702)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    if sukuna_unit == null:
        return harness.fail_result("missing sukuna active unit")
    if sukuna_unit.regular_skill_ids != ritual_loadout:
        return harness.fail_result("sukuna runtime loadout should mirror setup override")
    var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not legal_action_set.legal_skill_ids.has("sukuna_reverse_ritual"):
        return harness.fail_result("setup override should expose 反转术式 as legal action")
    if legal_action_set.legal_skill_ids.has("sukuna_hiraku"):
        return harness.fail_result("setup override should remove 开 from this battle loadout")
    sukuna_unit.current_hp = max(1, int(floor(float(sukuna_unit.max_hp) * 0.5)))
    var before_hp: int = sukuna_unit.current_hp
    var expected_gain: int = min(sukuna_unit.max_hp - before_hp, max(1, int(floor(float(sukuna_unit.max_hp) * 0.25))))
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_reverse_ritual",
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if sukuna_unit.current_hp - before_hp != expected_gain:
        return harness.fail_result("reverse ritual heal delta mismatch")
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_HEAL and String(log_event.payload_summary).find("heal") != -1:
            return harness.pass_result()
    return harness.fail_result("reverse ritual heal log missing")

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
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 1, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
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
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 3, "P1", "P1-A"),
        core.command_builder.build_command({
            "turn_index": 3,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "target_public_id": "P2-B",
        }),
    ])
    var on_exit_damage_events: int = 0
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_DAMAGE \
        and log_event.trigger_name == "on_exit" \
        and log_event.target_instance_id == target_unit.unit_instance_id:
            on_exit_damage_events += 1
    if hp_before_exit - target_unit.current_hp != 20:
        return harness.fail_result("double kamado on_exit damage mismatch: delta=%d events=%d" % [hp_before_exit - target_unit.current_hp, on_exit_damage_events])
    if on_exit_damage_events != 2:
        return harness.fail_result("double kamado should emit two on_exit damage events")
    return harness.pass_result()

func _test_sukuna_domain_expire_chain_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 704)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for domain expire test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 2, "P1", "P1-A"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    var hp_before_expire: int = target_unit.current_hp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_wait_command(core, 3, "P1", "P1-A"),
        _build_manual_wait_command(core, 3, "P2", "P2-A"),
    ])
    if battle_state.field_state != null:
        return harness.fail_result("malevolent shrine should expire after third turn")
    if hp_before_expire - target_unit.current_hp != 10:
        return harness.fail_result("malevolent shrine expire burst should deal resisted 10 damage")
    if int(sukuna_unit.stat_stages.get("attack", 0)) != 0 or int(sukuna_unit.stat_stages.get("sp_attack", 0)) != 0:
        return harness.fail_result("malevolent shrine 自然到期后应移除领域绑定增幅")
    var legal_action_set = core.legal_action_service.get_legal_actions(battle_state, "P1", content_index)
    if not legal_action_set.legal_skill_ids.has("sukuna_kai") \
    or not legal_action_set.legal_skill_ids.has("sukuna_hatsu") \
    or not legal_action_set.legal_skill_ids.has("sukuna_hiraku"):
        return harness.fail_result("domain expire should not seal sukuna normal skills after removing post-domain cooldown")
    var has_field_expire_log: bool = false
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
            has_field_expire_log = true
            break
    if not has_field_expire_log:
        return harness.fail_result("domain expire log missing")
    return harness.pass_result()

func _test_sukuna_domain_break_chain_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 705)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for domain break test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var hp_before_break: int = target_unit.current_hp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SWITCH,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "target_public_id": "P1-B",
        }),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    if battle_state.field_state != null:
        return harness.fail_result("malevolent shrine should break when creator leaves active slot")
    if target_unit.current_hp != hp_before_break:
        return harness.fail_result("field break should not trigger expire burst damage")
    if int(sukuna_unit.stat_stages.get("attack", 0)) != 0 or int(sukuna_unit.stat_stages.get("sp_attack", 0)) != 0:
        return harness.fail_result("malevolent shrine 打断后领域绑定增幅必须消失")
    for log_event in core.battle_logger.event_log:
        if log_event.event_type == EventTypesScript.EFFECT_FIELD_EXPIRE:
            return harness.fail_result("field break should not emit natural expire log")
        if log_event.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and String(log_event.payload_summary).find("skill_legality") != -1:
            return harness.fail_result("field break should not apply any post-domain seal rule_mod")
    return harness.pass_result()

func _test_sukuna_field_accuracy_override_path(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.skills["sukuna_hiraku"].accuracy = 0
    var battle_setup = _build_sukuna_setup(sample_factory)
    var battle_state = _build_battle_state(core, content_index, battle_setup, 706)
    var sukuna_unit = battle_state.get_side("P1").get_active_unit()
    var target_unit = battle_state.get_side("P2").get_active_unit()
    if sukuna_unit == null or target_unit == null:
        return harness.fail_result("missing active units for field accuracy override test")
    sukuna_unit.current_mp = sukuna_unit.max_mp
    sukuna_unit.ultimate_points = sukuna_unit.ultimate_points_cap
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.ULTIMATE,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sukuna_fukuma_mizushi",
        }),
        _build_manual_wait_command(core, 1, "P2", "P2-A"),
    ])
    var hp_before_cast: int = target_unit.current_hp
    sukuna_unit.current_mp = sukuna_unit.max_mp
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        _build_manual_skill_command(core, 2, "P1", "P1-A", "sukuna_hiraku"),
        _build_manual_wait_command(core, 2, "P2", "P2-A"),
    ])
    if target_unit.current_hp >= hp_before_cast:
        return harness.fail_result("field accuracy override should let zero-accuracy hiraku hit while domain is active")
    return harness.pass_result()

func _build_sukuna_setup(sample_factory, p1_regular_skill_overrides: Dictionary = {}):
    var battle_setup = sample_factory.build_sample_setup({"P1": p1_regular_skill_overrides})
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sukuna", "sample_mossaur", "sample_pyron"])
    battle_setup.sides[0].starting_index = 0
    battle_setup.sides[1].unit_definition_ids = PackedStringArray(["sample_tidekit", "sample_pyron", "sample_mossaur"])
    battle_setup.sides[1].starting_index = 0
    return battle_setup

func _build_battle_state(core, content_index, battle_setup, seed: int):
    core.rng_service.reset(seed)
    core.id_factory.reset()
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = core.id_factory.next_id("battle")
    battle_state.seed = seed
    battle_state.rng_stream_index = core.rng_service.get_stream_index()
    core.battle_initializer.initialize_battle(battle_state, content_index, battle_setup)
    return battle_state

func _build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.SKILL,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
        "skill_id": skill_id,
    })

func _build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
    return core.command_builder.build_command({
        "turn_index": turn_index,
        "command_type": CommandTypesScript.WAIT,
        "command_source": "manual",
        "side_id": side_id,
        "actor_public_id": actor_public_id,
    })

func _sum_unit_bst(unit_state) -> int:
    if unit_state == null:
        return 0
    return int(unit_state.max_hp) \
    + int(unit_state.base_attack) \
    + int(unit_state.base_defense) \
    + int(unit_state.base_sp_attack) \
    + int(unit_state.base_sp_defense) \
    + int(unit_state.base_speed) \
    + int(unit_state.max_mp)

func _resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
    var gap: int = abs(owner_total - opponent_total)
    for index in range(thresholds.size()):
        if gap <= int(thresholds[index]):
            return int(outputs[index])
    return default_value
