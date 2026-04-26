extends "res://tests/support/gdunit_suite_bridge.gd"

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")
const ActionDamageSegmentProbeSupportScript := preload("res://tests/support/action_damage_segment_probe_support.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")
const ObitoRuntimeContractSupportScript := preload("res://tests/support/obito_runtime_contract_support.gd")

var _action_damage_segment_probe_support = ActionDamageSegmentProbeSupportScript.new()
var _support = ObitoTestSupportScript.new()
var _contract_support = ObitoRuntimeContractSupportScript.new()


func test_obito_yinyang_dun_segment_mitigation_and_stack_contract() -> void:
	var baseline_result = _run_yinyang_guard_case(_harness, false, 1521, 0)
	if not bool(baseline_result.get("ok", false)):
		fail(str(baseline_result.get("error", "baseline yinyang guard case failed")))
		return
	var guarded_result = _run_yinyang_guard_case(_harness, true, 1522, 0)
	if not bool(guarded_result.get("ok", false)):
		fail(str(guarded_result.get("error", "guarded yinyang guard case failed")))
		return
	if int(guarded_result.get("hp_loss", -1)) >= int(baseline_result.get("hp_loss", -1)):
		fail("obito_yinyang_dun should reduce incoming multihit damage")
		return
	if int(guarded_result.get("yinyang_count", -1)) != 3:
		fail("obito_yinyang_dun should leave obito at 3 stacks after cast + 2 received segments")
		return

func test_obito_yinyang_dun_non_skill_segment_ignored_contract() -> void:
	var __legacy_result = _contract_support.run_yinyang_dun_non_skill_segment_ignored_contract(_harness)
	if typeof(__legacy_result) != TYPE_DICTIONARY or not bool(__legacy_result.get("ok", false)):
		fail(str(__legacy_result.get("error", "unknown error")))

func test_obito_yinyang_dun_same_side_segment_ignored_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), 1525)
	var obito_side = battle_state.get_side("P1")
	var obito = obito_side.get_active_unit() if obito_side != null else null
	if obito == null or obito_side == null or obito_side.team_units.size() < 2:
		fail("missing obito side context for same-side segment contract")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	var baseline_count := _support.count_effect_instances(obito, "obito_yinyang_zhili")
	if baseline_count != 1:
		fail("obito_yinyang_dun should seed exactly one initial stack before same-side trigger probe")
		return
	var ally = obito_side.team_units[1]
	var probe_command = _support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_qiudao_jiaotu")
	probe_command.actor_id = obito.unit_instance_id
	var invalid_code = _action_damage_segment_probe_support.run_enemy_segment_trigger(
		core,
		battle_state,
		content_index,
		probe_command,
		obito.unit_instance_id,
		ally.unit_instance_id,
		1,
		1,
		"fire"
	)
	if invalid_code != null:
		fail("same-side segment trigger probe should not invalidate battle: %s" % str(invalid_code))
		return
	if _support.count_effect_instances(obito, "obito_yinyang_zhili") != baseline_count:
		fail("obito_yinyang_dun should ignore same-side damage segment triggers")
		return

func test_obito_yinyang_dun_stack_cap_contract() -> void:
	var capped_result = _run_yinyang_guard_case(_harness, true, 1523, 5)
	if not bool(capped_result.get("ok", false)):
		fail(str(capped_result.get("error", "capped yinyang guard case failed")))
		return
	if int(capped_result.get("yinyang_count", -1)) != 5:
		fail("obito_yinyang_dun should respect the 5-stack cap during multihit guard")
		return
	if int(capped_result.get("defense_stage", -1)) != 1 or int(capped_result.get("sp_defense_stage", -1)) != 1:
		fail("obito_yinyang_dun should still grant stat stages even when yinyang stacks are capped")
		return


@warning_ignore("shadowed_global_identifier")
func _run_yinyang_guard_case(harness, use_guard: bool, seed: int, preseed_stacks: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"ok": false, "error": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"ok": false, "error": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	var skill = _build_enemy_multihit_skill("test_obito_yinyang_multihit_skill")
	content_index.register_resource(skill)
	content_index.units["sample_pyron"].skill_ids[0] = skill.id
	var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), seed)
	var obito = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if obito == null or target == null:
		return {"ok": false, "error": "missing active units for obito yinyang guard case"}
	var yinyang_definition = content_index.effects.get("obito_yinyang_zhili", null)
	if yinyang_definition == null:
		return {"ok": false, "error": "missing obito_yinyang_zhili definition"}
	for _i in range(preseed_stacks):
		if core.service("effect_instance_service").create_instance(yinyang_definition, obito.unit_instance_id, battle_state, "test_preseed_yinyang", 2, obito.base_speed) == null:
			return {"ok": false, "error": "failed to preseed yinyang stack"}
	var before_hp := int(obito.current_hp)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun") if use_guard else _support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", skill.id),
	])
	return {
		"ok": true,
		"hp_loss": before_hp - int(obito.current_hp),
		"yinyang_count": _support.count_effect_instances(obito, "obito_yinyang_zhili"),
		"defense_stage": int(obito.get_effective_stage("defense")),
		"sp_defense_stage": int(obito.get_effective_stage("sp_defense")),
	}

func _build_enemy_multihit_skill(skill_id: String):
	var skill = SkillDefinitionScript.new()
	skill.id = skill_id
	skill.display_name = skill_id
	skill.damage_kind = "special"
	skill.power = 20
	skill.accuracy = 100
	skill.mp_cost = 0
	skill.priority = 0
	skill.combat_type_id = ""
	skill.targeting = "enemy_active_slot"
	var segment = SkillDamageSegmentScript.new()
	segment.repeat_count = 2
	segment.power = 20
	segment.combat_type_id = "fire"
	segment.damage_kind = "special"
	skill.damage_segments.append(segment)
	return skill
