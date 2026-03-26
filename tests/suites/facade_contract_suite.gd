extends RefCounted
class_name FacadeContractSuite

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("full_open_public_snapshot_contract", failures, Callable(self, "_test_full_open_public_snapshot_contract").bind(harness))
    runner.run_test("effect_roll_logging_semantics", failures, Callable(self, "_test_effect_roll_logging_semantics").bind(harness))

func _test_full_open_public_snapshot_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")

    var init_result = core.facade.initialize_battle({
        "battle_seed": 301,
        "content_snapshot_paths": sample_factory.content_snapshot_paths(),
        "battle_setup": sample_factory.build_sample_setup(),
    })
    if init_result == null:
        return harness.fail_result("facade initialize_battle returned null")
    var battle_id: String = str(init_result.get("battle_id", ""))
    if battle_id.is_empty():
        return harness.fail_result("facade initialize_battle missing battle_id")
    var public_snapshot = init_result.get("public_snapshot", null)
    if typeof(public_snapshot) != TYPE_DICTIONARY:
        return harness.fail_result("facade initialize_battle missing public_snapshot")
    if not public_snapshot.has("visibility_mode") or str(public_snapshot["visibility_mode"]) != "prototype_full_open":
        return harness.fail_result("public_snapshot visibility_mode should be prototype_full_open")
    if not public_snapshot.has("field") or typeof(public_snapshot["field"]) != TYPE_DICTIONARY:
        return harness.fail_result("public_snapshot should include field snapshot")
    if not public_snapshot.has("sides") or public_snapshot["sides"].size() != 2:
        return harness.fail_result("public_snapshot should include 2 sides")

    for side_snapshot in public_snapshot["sides"]:
        if typeof(side_snapshot) != TYPE_DICTIONARY:
            return harness.fail_result("side snapshot should be Dictionary")
        if not side_snapshot.has("active_public_id") or not side_snapshot.has("active_hp") or not side_snapshot.has("active_mp"):
            return harness.fail_result("legacy active fields missing in side snapshot")
        if not side_snapshot.has("bench_public_ids") or not side_snapshot.has("team_units"):
            return harness.fail_result("side snapshot missing bench/team fields")
        if side_snapshot["team_units"].size() != 3:
            return harness.fail_result("team_units should include 3 entries per side")

    var prebattle_public_teams = init_result.get("prebattle_public_teams", null)
    if typeof(prebattle_public_teams) != TYPE_ARRAY or prebattle_public_teams.size() != 2:
        return harness.fail_result("initialize_battle should expose prebattle_public_teams")
    if prebattle_public_teams != public_snapshot.get("prebattle_public_teams", []):
        return harness.fail_result("prebattle_public_teams should equal snapshot payload")
    var snapshot_after_init = core.facade.build_public_snapshot(battle_id)
    if snapshot_after_init.get("prebattle_public_teams", []).size() != 2:
        return harness.fail_result("build_public_snapshot should keep prebattle_public_teams")
    if _contains_key_recursive(public_snapshot, "unit_instance_id"):
        return harness.fail_result("public_snapshot leaks unit_instance_id")
    if _contains_key_recursive(prebattle_public_teams, "unit_instance_id"):
        return harness.fail_result("prebattle_public_teams leaks unit_instance_id")
    return harness.pass_result()

func _test_effect_roll_logging_semantics(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var tie_payload_a = StatModPayloadScript.new()
    tie_payload_a.payload_type = "stat_mod"
    tie_payload_a.stat_name = "attack"
    tie_payload_a.stage_delta = 1
    var tie_effect_a = EffectDefinitionScript.new()
    tie_effect_a.id = "test_effect_roll_tie_a"
    tie_effect_a.display_name = "Effect Roll Tie A"
    tie_effect_a.scope = "self"
    tie_effect_a.duration_mode = "permanent"
    tie_effect_a.trigger_names = PackedStringArray(["on_cast"])
    tie_effect_a.payloads.clear()
    tie_effect_a.payloads.append(tie_payload_a)
    content_index.register_resource(tie_effect_a)

    var tie_payload_b = StatModPayloadScript.new()
    tie_payload_b.payload_type = "stat_mod"
    tie_payload_b.stat_name = "defense"
    tie_payload_b.stage_delta = 1
    var tie_effect_b = EffectDefinitionScript.new()
    tie_effect_b.id = "test_effect_roll_tie_b"
    tie_effect_b.display_name = "Effect Roll Tie B"
    tie_effect_b.scope = "self"
    tie_effect_b.duration_mode = "permanent"
    tie_effect_b.trigger_names = PackedStringArray(["on_cast"])
    tie_effect_b.payloads.clear()
    tie_effect_b.payloads.append(tie_payload_b)
    content_index.register_resource(tie_effect_b)

    var tie_skill = SkillDefinitionScript.new()
    tie_skill.id = "test_effect_roll_tie_skill"
    tie_skill.display_name = "Effect Roll Tie Skill"
    tie_skill.damage_kind = "none"
    tie_skill.power = 0
    tie_skill.accuracy = 100
    tie_skill.mp_cost = 0
    tie_skill.priority = 0
    tie_skill.targeting = "self"
    tie_skill.effects_on_cast_ids = PackedStringArray([tie_effect_a.id, tie_effect_b.id])
    content_index.register_resource(tie_skill)

    var single_payload = StatModPayloadScript.new()
    single_payload.payload_type = "stat_mod"
    single_payload.stat_name = "sp_attack"
    single_payload.stage_delta = 1
    var single_effect = EffectDefinitionScript.new()
    single_effect.id = "test_effect_roll_single_effect"
    single_effect.display_name = "Effect Roll Single"
    single_effect.scope = "self"
    single_effect.duration_mode = "permanent"
    single_effect.trigger_names = PackedStringArray(["on_cast"])
    single_effect.payloads.clear()
    single_effect.payloads.append(single_payload)
    content_index.register_resource(single_effect)

    var single_skill = SkillDefinitionScript.new()
    single_skill.id = "test_effect_roll_single_skill"
    single_skill.display_name = "Effect Roll Single Skill"
    single_skill.damage_kind = "none"
    single_skill.power = 0
    single_skill.accuracy = 100
    single_skill.mp_cost = 0
    single_skill.priority = 0
    single_skill.targeting = "self"
    single_skill.effects_on_cast_ids = PackedStringArray([single_effect.id])
    content_index.register_resource(single_skill)

    if not content_index.units["sample_pyron"].skill_ids.has(tie_skill.id):
        content_index.units["sample_pyron"].skill_ids.append(tie_skill.id)
    if not content_index.units["sample_pyron"].skill_ids.has(single_skill.id):
        content_index.units["sample_pyron"].skill_ids.append(single_skill.id)

    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 302)
    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": tie_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ])

    var tie_effect_log_count: int = 0
    for ev in core.battle_logger.event_log:
        if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.trigger_name == "on_cast" and String(ev.source_instance_id).begins_with("action_"):
            if String(ev.payload_summary).find("attack") != -1 or String(ev.payload_summary).find("defense") != -1:
                tie_effect_log_count += 1
                if ev.effect_roll == null:
                    return harness.fail_result("tie-group effect logs should carry effect_roll")
    if tie_effect_log_count != 2:
        return harness.fail_result("expected 2 tie-group effect logs, got %d" % tie_effect_log_count)

    core.turn_loop_controller.run_turn(battle_state, content_index, [
        core.command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": single_skill.id,
        }),
        core.command_builder.build_command({
            "turn_index": 2,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
            "skill_id": "sample_whiff",
        }),
    ])

    for i in range(core.battle_logger.event_log.size() - 1, -1, -1):
        var ev = core.battle_logger.event_log[i]
        if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.trigger_name == "on_cast" and String(ev.payload_summary).find("sp_attack") != -1:
            if ev.effect_roll != null:
                return harness.fail_result("single effect event should keep effect_roll as null")
            return harness.pass_result()
    return harness.fail_result("single effect event log missing for effect_roll null check")

func _contains_key_recursive(value, expected_key: String) -> bool:
    if typeof(value) == TYPE_DICTIONARY:
        for key in value.keys():
            if str(key) == expected_key:
                return true
            if _contains_key_recursive(value[key], expected_key):
                return true
    elif typeof(value) == TYPE_ARRAY:
        for element in value:
            if _contains_key_recursive(element, expected_key):
                return true
    return false
