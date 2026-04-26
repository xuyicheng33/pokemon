extends "res://test/suites/multihit_skill_runtime/base.gd"

func test_multihit_skill_validation_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)

	var bad_skill = SkillDefinitionScript.new()
	bad_skill.id = "test_bad_multihit_skill"
	bad_skill.display_name = "Bad Multihit Skill"
	bad_skill.damage_kind = "special"
	bad_skill.power = 0
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

	var drift_skill = SkillDefinitionScript.new()
	drift_skill.id = "test_bad_multihit_truth_skill"
	drift_skill.display_name = "Bad Multihit Truth Skill"
	drift_skill.damage_kind = "special"
	drift_skill.power = 5
	drift_skill.accuracy = 100
	drift_skill.mp_cost = 0
	drift_skill.priority = 0
	drift_skill.targeting = "enemy_active_slot"
	var drift_segment = SkillDamageSegmentScript.new()
	drift_segment.repeat_count = 1
	drift_segment.power = 20
	drift_segment.damage_kind = "special"
	drift_segment.combat_type_id = ""
	var drift_segments: Array[Resource] = [drift_segment]
	drift_skill.damage_segments = drift_segments
	content_index.register_resource(drift_skill)

	var filtered_segment_effect = _build_filtered_on_segment_mp_loss_effect(
		"test_allowed_segment_filter_effect",
		"skill",
		"fire",
		-2
	)
	content_index.register_resource(filtered_segment_effect)

	var errors: Array = content_index.validate_snapshot()
	if not _has_error(errors, "skill[test_bad_multihit_skill].damage_segments[0].repeat_count must be > 0, got 0"):
		fail("multihit validation should reject non-positive repeat_count")
		return
	if not _has_error(errors, "skill[test_bad_multihit_skill].damage_segments[0].combat_type_id missing combat type: missing_combat_type"):
		fail("multihit validation should reject missing segment combat type")
		return
	if _has_error(errors, "skill[test_bad_multihit_skill].power must be > 0 for damage skills, got 0") \
	or _has_error(errors, "skill[test_bad_multihit_skill].power must be > 0 for non-segment damage skills, got 0"):
		fail("multihit validation should allow top-level power=0 when damage_segments carry the damage truth")
		return
	if not _has_error(errors, "skill[test_bad_multihit_truth_skill].power must be 0 when damage_segments is present, got 5"):
		fail("multihit validation should reject non-zero top-level power when damage_segments is present")
		return
	if _has_error(errors, "effect[test_allowed_segment_filter_effect].required_incoming_command_types only allowed for on_receive_action_hit/on_receive_action_damage_segment"):
		fail("multihit validation should allow command filters on on_receive_action_damage_segment")
		return
	if _has_error(errors, "effect[test_allowed_segment_filter_effect].required_incoming_combat_type_ids only allowed for on_receive_action_hit/on_receive_action_damage_segment"):
		fail("multihit validation should allow combat filters on on_receive_action_damage_segment")
		return
