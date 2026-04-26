extends "res://tests/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const DomainRoleTestSupportScript := preload("res://tests/support/domain_role_test_support.gd")

var _support = DomainRoleTestSupportScript.new()


func test_persistent_stat_stage_switch_and_faint_contract() -> void:
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

	var stat_payload = StatModPayloadScript.new()
	stat_payload.payload_type = "stat_mod"
	stat_payload.stat_name = "attack"
	stat_payload.stage_delta = 2
	stat_payload.retention_mode = "persist_on_switch"
	var stat_effect = EffectDefinitionScript.new()
	stat_effect.id = "test_persistent_attack_up"
	stat_effect.display_name = "Persistent Attack Up"
	stat_effect.scope = "self"
	stat_effect.duration_mode = "permanent"
	stat_effect.trigger_names = PackedStringArray(["on_cast"])
	stat_effect.payloads.append(stat_payload)
	content_index.register_resource(stat_effect)

	var buff_skill = SkillDefinitionScript.new()
	buff_skill.id = "test_persistent_attack_skill"
	buff_skill.display_name = "Persistent Attack Skill"
	buff_skill.damage_kind = "none"
	buff_skill.accuracy = 100
	buff_skill.mp_cost = 0
	buff_skill.priority = 0
	buff_skill.targeting = "self"
	buff_skill.effects_on_cast_ids = PackedStringArray([stat_effect.id])
	content_index.register_resource(buff_skill)
	content_index.units["sample_pyron"].skill_ids[0] = buff_skill.id

	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 901)
	var actor = battle_state.get_side("P1").get_active_unit()
	if actor == null:
		fail("missing actor for persistent stat switch contract")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", buff_skill.id),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	if int(actor.persistent_stat_stages.get("attack", 0)) != 2:
		fail("persist_on_switch stat mod should write into persistent_stat_stages")
		return
	if actor.get_effective_stage("attack") != 2:
		fail("effective attack stage should include persistent bucket")
		return

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 2, "P1", "P1-A", "P1-B"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	if int(actor.stat_stages.get("attack", 0)) != 0:
		fail("temporary stat stages should still clear on switch")
		return
	if int(actor.persistent_stat_stages.get("attack", 0)) != 2:
		fail("persistent stat stages should survive manual switch")
		return

	core.service("leave_service").leave_unit(battle_state, actor, "faint", content_index)
	if int(actor.persistent_stat_stages.get("attack", 0)) != 0:
		fail("persistent stat stages should clear on faint")
		return

func test_persistent_stat_stage_effective_read_contract() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 902)
	var actor = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if actor == null or target == null:
		fail("missing active units for persistent stat effective read contract")
		return
	actor.persistent_stat_stages["speed"] = 1
	actor.persistent_stat_stages["sp_attack"] = 2

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "sample_pyro_blast"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", "sample_strike"),
	])
	var first_action_actor_id := _find_first_action_actor_id(core.service("battle_logger").event_log)
	if first_action_actor_id != actor.unit_instance_id:
		fail("persistent speed stage should affect queue order, first actor_id=%s" % first_action_actor_id)
		return
	var expected_damage: int = core.service("damage_service").apply_final_mod(
		core.service("damage_service").calc_base_damage(
			battle_state.battle_level,
			int(content_index.skills["sample_pyro_blast"].power),
			core.service("stat_calculator").calc_effective_stat(actor.base_sp_attack, 2),
			target.base_sp_defense
		),
		core.service("combat_type_service").calc_effectiveness("fire", target.combat_type_ids)
	)
	var actual_damage: int = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if actual_damage != expected_damage:
		fail("persistent sp_attack stage should affect direct damage: expected=%d actual=%d" % [expected_damage, actual_damage])
		return


func _find_first_action_actor_id(event_log: Array) -> String:
	for event in event_log:
		if event.event_type == EventTypesScript.ACTION_CAST:
			return String(event.actor_id)
	return ""
