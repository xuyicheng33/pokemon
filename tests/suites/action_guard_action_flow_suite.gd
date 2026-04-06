extends RefCounted
class_name ActionGuardActionFlowSuite

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("action_effects_on_kill_dispatch", failures, Callable(self, "_test_action_effects_on_kill_dispatch").bind(harness))
	runner.run_test("on_cast_self_faint_keeps_action_chain", failures, Callable(self, "_test_on_cast_self_faint_keeps_action_chain").bind(harness))
	runner.run_test("action_failed_post_start_target_missing", failures, Callable(self, "_test_action_failed_post_start_target_missing").bind(harness))
	runner.run_test("double_faint_reason_preserved", failures, Callable(self, "_test_double_faint_reason_preserved").bind(harness))
	runner.run_test("battle_end_system_chain", failures, Callable(self, "_test_battle_end_system_chain").bind(harness))

func _test_action_effects_on_kill_dispatch(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var kill_effect_payload = StatModPayloadScript.new()
	kill_effect_payload.payload_type = "stat_mod"
	kill_effect_payload.stat_name = "attack"
	kill_effect_payload.stage_delta = 1
	var kill_effect = EffectDefinitionScript.new()
	kill_effect.id = "test_action_kill_effect"
	kill_effect.display_name = "Action Kill Effect"
	kill_effect.scope = "self"
	kill_effect.trigger_names = PackedStringArray(["on_kill"])
	kill_effect.payloads.clear()
	kill_effect.payloads.append(kill_effect_payload)
	content_index.register_resource(kill_effect)

	var kill_skill = SkillDefinitionScript.new()
	kill_skill.id = "test_action_kill_skill"
	kill_skill.display_name = "Action Kill Skill"
	kill_skill.damage_kind = "physical"
	kill_skill.power = 40
	kill_skill.accuracy = 100
	kill_skill.mp_cost = 0
	kill_skill.priority = 0
	kill_skill.targeting = "enemy_active_slot"
	kill_skill.effects_on_kill_ids = PackedStringArray([kill_effect.id])
	content_index.register_resource(kill_skill)
	if not content_index.units["sample_pyron"].skill_ids.has(kill_skill.id):
		content_index.units["sample_pyron"].skill_ids[0] = kill_skill.id

	var kill_state = harness.build_initialized_battle(core, content_index, sample_factory, 109)
	var kill_p1_active = kill_state.get_side("P1").get_active_unit()
	kill_p1_active.base_speed = 999
	var kill_p2_active = kill_state.get_side("P2").get_active_unit()
	kill_p2_active.current_hp = 1
	core.service("turn_loop_controller").run_turn(kill_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": kill_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
	])
	var has_kill_effect_log: bool = false
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.target_instance_id == kill_p1_active.unit_instance_id and str(ev.source_instance_id).begins_with("action_"):
			has_kill_effect_log = true
			break
	if not has_kill_effect_log:
		return harness.fail_result("effects_on_kill did not trigger on kill")

	var non_kill_state = harness.build_initialized_battle(core, content_index, sample_factory, 110)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(non_kill_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": kill_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
	])
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("action_"):
			return harness.fail_result("effects_on_kill should not trigger without kill")
	return harness.pass_result()

func _test_on_cast_self_faint_keeps_action_chain(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var self_damage_payload = DamagePayloadScript.new()
	self_damage_payload.payload_type = "damage"
	self_damage_payload.amount = 999
	self_damage_payload.use_formula = false
	var self_damage_effect = EffectDefinitionScript.new()
	self_damage_effect.id = "test_on_cast_self_faint_effect"
	self_damage_effect.display_name = "On Cast Self Faint Effect"
	self_damage_effect.scope = "self"
	self_damage_effect.trigger_names = PackedStringArray(["on_cast"])
	self_damage_effect.payloads.clear()
	self_damage_effect.payloads.append(self_damage_payload)
	content_index.register_resource(self_damage_effect)
	var self_faint_skill = SkillDefinitionScript.new()
	self_faint_skill.id = "test_on_cast_self_faint_skill"
	self_faint_skill.display_name = "On Cast Self Faint Skill"
	self_faint_skill.damage_kind = "none"
	self_faint_skill.power = 0
	self_faint_skill.accuracy = 100
	self_faint_skill.mp_cost = 0
	self_faint_skill.priority = 0
	self_faint_skill.targeting = "enemy_active_slot"
	self_faint_skill.effects_on_cast_ids = PackedStringArray([self_damage_effect.id])
	content_index.register_resource(self_faint_skill)
	if not content_index.units["sample_pyron"].skill_ids.has(self_faint_skill.id):
		content_index.units["sample_pyron"].skill_ids[0] = self_faint_skill.id
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 312)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	if p1_active == null:
		return harness.fail_result("missing P1 active unit")
	p1_active.base_speed = 999
	var actor_unit_id: String = p1_active.unit_instance_id
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": self_faint_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_whiff",
		}),
	])
	var self_damage_idx := -1
	var action_hit_idx := -1
	var faint_idx := -1
	var replace_idx := -1
	var action_source_id: String = ""
	for i in range(core.service("battle_logger").event_log.size()):
		var ev = core.service("battle_logger").event_log[i]
		if action_source_id.is_empty() and ev.event_type == EventTypesScript.ACTION_CAST and ev.actor_id == actor_unit_id:
			action_source_id = str(ev.source_instance_id)
		if self_damage_idx == -1 and ev.event_type == EventTypesScript.EFFECT_DAMAGE and ev.trigger_name == "on_cast" and ev.target_instance_id == actor_unit_id:
			self_damage_idx = i
		if action_hit_idx == -1 and not action_source_id.is_empty() and ev.event_type == EventTypesScript.ACTION_HIT and ev.source_instance_id == action_source_id:
			action_hit_idx = i
		if faint_idx == -1 and ev.event_type == EventTypesScript.STATE_FAINT and ev.target_instance_id == actor_unit_id:
			faint_idx = i
		if replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE and faint_idx != -1 and i > faint_idx:
			replace_idx = i
	if self_damage_idx == -1:
		return harness.fail_result("on_cast self damage event missing")
	if action_hit_idx == -1:
		return harness.fail_result("action hit missing after on_cast self damage")
	if faint_idx == -1:
		return harness.fail_result("state_faint missing for self-fainted actor")
	if not (self_damage_idx < action_hit_idx and action_hit_idx < faint_idx):
		return harness.fail_result("on_cast self faint ordering mismatch")
	if replace_idx == -1:
		return harness.fail_result("state_replace missing after self-faint window")
	return harness.pass_result()

func _test_action_failed_post_start_target_missing(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 114)

	var actor = battle_state.get_unit_by_public_id("P1-A")
	if actor == null:
		return harness.fail_result("missing P1-A actor")
	var command = core.service("command_builder").build_command({
		"turn_index": 1,
		"command_type": CommandTypesScript.SKILL,
		"command_source": "manual",
		"side_id": "P1",
		"actor_id": actor.unit_instance_id,
		"skill_id": "sample_strike",
	})
	var queued_action = core.service("action_queue_builder").build_queue([command], battle_state, content_index)[0]
	var p2_side = battle_state.get_side("P2")
	p2_side.clear_active_unit()

	var action_result = core.service("action_executor").execute_action(queued_action, battle_state, content_index)
	if action_result.invalid_battle_code != null:
		return harness.fail_result("target missing at execution start should not raise invalid_battle")
	if action_result.result_type != "action_failed_post_start":
		return harness.fail_result("expected action_failed_post_start when target slot missing, got %s" % str(action_result.result_type))
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.ACTION_FAILED_POST_START:
			return harness.pass_result()
	return harness.fail_result("missing action_failed_post_start log event")

func _test_double_faint_reason_preserved(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 219)
	for side_state in battle_state.sides:
		for unit_state in side_state.team_units:
			unit_state.current_hp = 0
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if not battle_state.battle_result.finished:
		return harness.fail_result("battle should finish when both sides have no available units")
	if battle_state.battle_result.result_type != "draw":
		return harness.fail_result("double faint should end in draw")
	if battle_state.battle_result.reason != "double_faint":
		return harness.fail_result("double faint reason should remain double_faint, got %s" % str(battle_state.battle_result.reason))
	return harness.pass_result()

func _test_battle_end_system_chain(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var turn_start_battle = harness.build_initialized_battle(core, content_index, sample_factory, 261)
	var turn_start_side = turn_start_battle.get_side("P2")
	if turn_start_side == null:
		return harness.fail_result("turn_start side missing")
	for unit_state in turn_start_side.team_units:
		unit_state.current_hp = 0
	core.service("turn_loop_controller").run_turn(turn_start_battle, content_index, [])
	var turn_start_battle_end = harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.RESULT_BATTLE_END)
	if turn_start_battle_end == null:
		return harness.fail_result("turn_start battle_end event missing")
	if turn_start_battle_end.command_type != EventTypesScript.SYSTEM_TURN_START:
		return harness.fail_result("turn_start battle_end should inherit system:turn_start")
	if turn_start_battle_end.chain_origin != "turn_start":
		return harness.fail_result("turn_start battle_end chain_origin should be turn_start")

	var turn_limit_battle = harness.build_initialized_battle(core, content_index, sample_factory, 262)
	turn_limit_battle.max_turn = 1
	core.service("turn_loop_controller").run_turn(turn_limit_battle, content_index, [])
	var turn_limit_event = harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.SYSTEM_TURN_LIMIT)
	if turn_limit_event == null:
		return harness.fail_result("turn_limit event missing")
	if turn_limit_event.chain_origin != "turn_end":
		return harness.fail_result("turn_limit chain_origin should be turn_end")
	var turn_limit_battle_end = harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.RESULT_BATTLE_END)
	if turn_limit_battle_end == null:
		return harness.fail_result("turn_limit battle_end event missing")
	if turn_limit_battle_end.command_type != EventTypesScript.SYSTEM_TURN_LIMIT:
		return harness.fail_result("turn_limit battle_end should inherit system:turn_limit")
	if turn_limit_battle_end.chain_origin != "turn_end":
		return harness.fail_result("turn_limit battle_end chain_origin should be turn_end")

	var execution_battle = harness.build_initialized_battle(core, content_index, sample_factory, 263)
	var execution_p1_active = execution_battle.get_side("P1").get_active_unit()
	var execution_p2_side = execution_battle.get_side("P2")
	if execution_p1_active == null or execution_p2_side == null:
		return harness.fail_result("execution battle setup missing active units")
	for unit_state in execution_p2_side.team_units:
		unit_state.current_hp = 0
	var execution_p2_active = execution_p2_side.get_active_unit()
	if execution_p2_active == null:
		return harness.fail_result("execution battle missing target active unit")
	execution_p2_active.current_hp = 1
	execution_p1_active.base_speed = 999
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(execution_battle, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_strike",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var execution_battle_end = harness.find_last_event(core.service("battle_logger").event_log, EventTypesScript.RESULT_BATTLE_END)
	if execution_battle_end == null:
		return harness.fail_result("execution battle_end event missing")
	if execution_battle_end.command_type != CommandTypesScript.SKILL:
		return harness.fail_result("execution battle_end should inherit root action command_type")
	if execution_battle_end.chain_origin != "action":
		return harness.fail_result("execution battle_end chain_origin should stay action")
	if String(execution_battle_end.actor_id) != String(execution_p1_active.unit_instance_id):
		return harness.fail_result("execution battle_end should inherit root action actor_id")
	return harness.pass_result()
