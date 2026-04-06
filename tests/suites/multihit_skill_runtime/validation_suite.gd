extends "res://tests/suites/multihit_skill_runtime/base.gd"
const BaseSuiteScript := preload("res://tests/suites/multihit_skill_runtime/base.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
    runner.run_test("multihit_skill_validation_contract", failures, Callable(self, "_test_multihit_skill_validation_contract").bind(harness))

func _test_multihit_skill_validation_contract(harness) -> Dictionary:
    var sample_factory = harness.build_sample_factory()
    if sample_factory == null:
        return harness.fail_result("SampleBattleFactory init failed")
    var content_index = harness.build_loaded_content_index(sample_factory)

    var bad_skill = SkillDefinitionScript.new()
    bad_skill.id = "test_bad_multihit_skill"
    bad_skill.display_name = "Bad Multihit Skill"
    bad_skill.damage_kind = "special"
    bad_skill.power = 20
    bad_skill.accuracy = 100
    bad_skill.mp_cost = 0
    bad_skill.priority = 0
    bad_skill.targeting = "enemy_active_slot"
    var bad_segment = SkillDamageSegmentScript.new()
    bad_segment.repeat_count = 0
    bad_segment.power = 20
    bad_segment.damage_kind = "special"
    bad_segment.combat_type_id = "missing_combat_type"
    var bad_segments: Array[Resource] = [bad_segment]
    bad_skill.damage_segments = bad_segments
    content_index.register_resource(bad_skill)

    var filtered_segment_effect = _build_filtered_on_segment_mp_loss_effect(
        "test_allowed_segment_filter_effect",
        "skill",
        "fire",
        -2
    )
    content_index.register_resource(filtered_segment_effect)

    var errors: Array = content_index.validate_snapshot()
    if not _has_error(errors, "skill[test_bad_multihit_skill].damage_segments[0].repeat_count must be > 0, got 0"):
        return harness.fail_result("multihit validation should reject non-positive repeat_count")
    if not _has_error(errors, "skill[test_bad_multihit_skill].damage_segments[0].combat_type_id missing combat type: missing_combat_type"):
        return harness.fail_result("multihit validation should reject missing segment combat type")
    if _has_error(errors, "effect[test_allowed_segment_filter_effect].required_incoming_command_types only allowed for on_receive_action_hit/on_receive_action_damage_segment"):
        return harness.fail_result("multihit validation should allow command filters on on_receive_action_damage_segment")
    if _has_error(errors, "effect[test_allowed_segment_filter_effect].required_incoming_combat_type_ids only allowed for on_receive_action_hit/on_receive_action_damage_segment"):
        return harness.fail_result("multihit validation should allow combat filters on on_receive_action_damage_segment")
    return harness.pass_result()
