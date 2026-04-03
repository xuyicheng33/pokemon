extends RefCounted
class_name SetupLoadoutSuite

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("candidate_skill_pool_validation", failures, Callable(self, "_test_candidate_skill_pool_validation").bind(harness))
    runner.run_test("setup_loadout_override_validation", failures, Callable(self, "_test_setup_loadout_override_validation").bind(harness))
    runner.run_test("runtime_regular_skill_loadout_contract", failures, Callable(self, "_test_runtime_regular_skill_loadout_contract").bind(harness))
    runner.run_test("same_side_duplicate_unit_forbidden", failures, Callable(self, "_test_same_side_duplicate_unit_forbidden").bind(harness))

func _test_candidate_skill_pool_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var cases: Array = [
        {
            "candidate_skill_ids": PackedStringArray(["sample_field_call", "sample_pyro_blast", "sample_whiff"]),
            "needle": "candidate_skill_ids must include default skill: sample_strike",
        },
        {
            "candidate_skill_ids": PackedStringArray(["sample_strike", "sample_field_call", "sample_field_call"]),
            "needle": "candidate_skill_ids duplicated skill: sample_field_call",
        },
        {
            "candidate_skill_ids": PackedStringArray(["sample_strike", "sample_field_call"]),
            "needle": "candidate_skill_ids must contain at least 3 entries",
        },
        {
            "candidate_skill_ids": PackedStringArray(["sample_strike", "sample_field_call", "sample_ultimate_burst"]),
            "needle": "candidate_skill_ids must not include ultimate_skill_id: sample_ultimate_burst",
        },
    ]
    for test_case in cases:
        var content_index = harness.build_loaded_content_index(sample_factory)
        var unit_definition = content_index.units["sample_pyron"]
        unit_definition.candidate_skill_ids = test_case["candidate_skill_ids"]
        var errors: Array = content_index.validate_snapshot()
        if not _has_error(errors, test_case["needle"]):
            return harness.fail_result("candidate skill validation missing error: %s" % test_case["needle"])
    return harness.pass_result()

func _test_setup_loadout_override_validation(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var candidate_pool := PackedStringArray(["sample_strike", "sample_whiff", "sample_tide_surge", "sample_field_call"])
    var cases: Array = [
        {
            "overrides": {3: PackedStringArray(["sample_field_call", "sample_whiff", "sample_tide_surge"])},
            "needle": "regular_skill_loadout_overrides slot out of range",
        },
        {
            "overrides": {0: PackedStringArray(["sample_field_call", "sample_whiff"])},
            "needle": "must contain exactly 3 skills",
        },
        {
            "overrides": {0: PackedStringArray(["sample_field_call", "sample_field_call", "sample_tide_surge"])},
            "needle": "duplicated skill: sample_field_call",
        },
        {
            "overrides": {0: PackedStringArray(["sample_field_call", "sample_tide_surge", "sample_pyro_blast"])},
            "needle": "skill not in candidate_skill_ids: sample_pyro_blast",
        },
        {
            "overrides": {1: PackedStringArray(["sample_quick_jab", "sample_vine_slash", "sample_strike"])},
            "needle": "must equal default skill_ids when candidate_skill_ids is empty",
        },
    ]
    for test_case in cases:
        var content_index = harness.build_loaded_content_index(sample_factory)
        content_index.units["sample_tidekit"].candidate_skill_ids = candidate_pool
        var battle_setup = sample_factory.build_sample_setup({"P1": test_case["overrides"]})
        battle_setup.sides[0].unit_definition_ids[0] = "sample_tidekit"
        var errors: Array = content_index.validate_setup(battle_setup)
        if not _has_error(errors, test_case["needle"]):
            return harness.fail_result("setup override validation missing error: %s" % test_case["needle"])
    return harness.pass_result()

func _test_runtime_regular_skill_loadout_contract(harness) -> Dictionary:
    var core_payload = harness.build_core()
    if core_payload.has("error"):
        return harness.fail_result(str(core_payload["error"]))
    var core = core_payload["core"]
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    content_index.units["sample_pyron"].candidate_skill_ids = PackedStringArray(["sample_strike", "sample_field_call", "sample_pyro_blast", "sample_whiff"])
    var override_loadout := PackedStringArray(["sample_strike", "sample_field_call", "sample_whiff"])
    var battle_setup = sample_factory.build_sample_setup({"P1": {0: override_loadout}})
    battle_setup.sides[0].starting_index = 0
    var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 901, battle_setup)
    var p1_active = battle_state.get_side("P1").get_active_unit()
    var p2_active = battle_state.get_side("P2").get_active_unit()
    if p1_active == null or p2_active == null:
        return harness.fail_result("missing active units for runtime loadout contract")
    if p1_active.regular_skill_ids != override_loadout:
        return harness.fail_result("P1 runtime regular_skill_ids should use setup override")
    if p2_active.regular_skill_ids != content_index.units["sample_tidekit"].skill_ids:
        return harness.fail_result("units without override should keep default loadout")
    var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
    if not legal_action_set.legal_skill_ids.has("sample_whiff"):
        return harness.fail_result("override loadout should expose swapped-in skill")
    if legal_action_set.legal_skill_ids.has("sample_pyro_blast"):
        return harness.fail_result("override loadout should hide swapped-out default skill")
    var public_snapshot = core.service("public_snapshot_builder").build_public_snapshot(battle_state, content_index)
    var prebattle_teams: Array = public_snapshot.get("prebattle_public_teams", [])
    if prebattle_teams.size() != 2:
        return harness.fail_result("prebattle_public_teams should expose both sides")
    var p1_units: Array = prebattle_teams[0].get("units", [])
    var p2_units: Array = prebattle_teams[1].get("units", [])
    if p1_units.is_empty() or p2_units.is_empty():
        return harness.fail_result("prebattle_public_teams should expose unit payloads")
    if p1_units[0].get("skill_ids", PackedStringArray()) != override_loadout:
        return harness.fail_result("public snapshot should expose battle-specific equipped skills")
    if p2_units[0].get("skill_ids", PackedStringArray()) != content_index.units["sample_tidekit"].skill_ids:
        return harness.fail_result("public snapshot should keep default skills for slots without override")
    core.service("turn_loop_controller").run_turn(battle_state, content_index, [
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.SKILL,
            "command_source": "manual",
            "side_id": "P1",
            "actor_public_id": "P1-A",
            "skill_id": "sample_field_call",
        }),
        core.service("command_builder").build_command({
            "turn_index": 1,
            "command_type": CommandTypesScript.WAIT,
            "command_source": "manual",
            "side_id": "P2",
            "actor_public_id": "P2-A",
        }),
    ])
    if battle_state.field_state == null or battle_state.field_state.field_def_id != "sample_focus_field":
        return harness.fail_result("swapped-in skill should remain executable at runtime")
    return harness.pass_result()

func _test_same_side_duplicate_unit_forbidden(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)
    var battle_setup = sample_factory.build_sample_setup()
    battle_setup.sides[0].unit_definition_ids = PackedStringArray(["sample_pyron", "sample_pyron", "sample_tidekit"])
    var errors: Array = content_index.validate_setup(battle_setup)
    if not _has_error(errors, "duplicated unit_definition_id: sample_pyron"):
        return harness.fail_result("same-side duplicate units should fail fast once duplicate-role ban is live")
    return harness.pass_result()

func _has_error(errors: Array, needle: String) -> bool:
    for error_msg in errors:
        if String(error_msg).find(needle) != -1:
            return true
    return false
