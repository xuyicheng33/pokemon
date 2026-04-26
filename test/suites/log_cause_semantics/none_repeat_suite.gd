extends "res://test/suites/log_cause_semantics/shared.gd"

func test_apply_effect_none_repeat_skips_log() -> void:
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
	var marker_effect = EffectDefinitionScript.new()
	marker_effect.id = "test_none_marker"
	marker_effect.display_name = "None Marker"
	marker_effect.scope = "self"
	marker_effect.duration_mode = "permanent"
	marker_effect.stacking = "none"
	marker_effect.trigger_names = PackedStringArray()
	marker_effect.payloads.clear()
	content_index.register_resource(marker_effect)
	var apply_payload = ApplyEffectPayloadScript.new()
	apply_payload.payload_type = "apply_effect"
	apply_payload.effect_definition_id = marker_effect.id
	var apply_effect = EffectDefinitionScript.new()
	apply_effect.id = "test_apply_none_marker"
	apply_effect.display_name = "Apply None Marker"
	apply_effect.scope = "target"
	apply_effect.duration_mode = "permanent"
	apply_effect.trigger_names = PackedStringArray(["on_cast"])
	apply_effect.payloads.clear()
	apply_effect.payloads.append(apply_payload)
	content_index.register_resource(apply_effect)
	var mark_skill = SkillDefinitionScript.new()
	mark_skill.id = "test_none_marker_skill"
	mark_skill.display_name = "None Marker Skill"
	mark_skill.damage_kind = "none"
	mark_skill.power = 0
	mark_skill.accuracy = 100
	mark_skill.mp_cost = 0
	mark_skill.priority = 0
	mark_skill.targeting = "enemy_active_slot"
	mark_skill.effects_on_cast_ids = PackedStringArray([apply_effect.id])
	content_index.register_resource(mark_skill)
	content_index.units["sample_pyron"].skill_ids[0] = mark_skill.id
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 244)
	var commands_turn_1: Array = [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": mark_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_whiff",
		}),
	]
	var commands_turn_2: Array = [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": mark_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_whiff",
		}),
	]
	core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_1)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_2)
	var target_unit = battle_state.get_side("P2").get_active_unit()
	var apply_events := 0
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_APPLY_EFFECT and String(ev.payload_summary).find(marker_effect.id) != -1:
			apply_events += 1
	if apply_events != 1:
		fail("stacking=none effect should emit exactly one apply log while the instance remains active")
		return
	var marker_count := 0
	for effect_instance in target_unit.effect_instances:
		if effect_instance.def_id == marker_effect.id:
			marker_count += 1
	if marker_count != 1:
		fail("stacking=none effect should keep exactly one runtime instance after repeated apply")
		return

func test_rule_mod_none_repeat_skips_log() -> void:
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
	var rule_mod_payload = RuleModPayloadScript.new()
	rule_mod_payload.payload_type = "rule_mod"
	rule_mod_payload.mod_kind = "mp_regen"
	rule_mod_payload.mod_op = "add"
	rule_mod_payload.value = 2
	rule_mod_payload.scope = "target"
	rule_mod_payload.duration_mode = "permanent"
	rule_mod_payload.decrement_on = "turn_end"
	rule_mod_payload.stacking = "none"
	var apply_effect = EffectDefinitionScript.new()
	apply_effect.id = "test_apply_none_rule_mod"
	apply_effect.display_name = "Apply None Rule Mod"
	apply_effect.scope = "target"
	apply_effect.duration_mode = "permanent"
	apply_effect.trigger_names = PackedStringArray(["on_cast"])
	apply_effect.payloads.clear()
	apply_effect.payloads.append(rule_mod_payload)
	content_index.register_resource(apply_effect)
	var mark_skill = SkillDefinitionScript.new()
	mark_skill.id = "test_none_rule_mod_skill"
	mark_skill.display_name = "None Rule Mod Skill"
	mark_skill.damage_kind = "none"
	mark_skill.power = 0
	mark_skill.accuracy = 100
	mark_skill.mp_cost = 0
	mark_skill.priority = 0
	mark_skill.targeting = "enemy_active_slot"
	mark_skill.effects_on_cast_ids = PackedStringArray([apply_effect.id])
	content_index.register_resource(mark_skill)
	content_index.units["sample_pyron"].skill_ids[0] = mark_skill.id
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 245)
	var commands_turn_1: Array = [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": mark_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_whiff",
		}),
	]
	var commands_turn_2: Array = [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": mark_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_whiff",
		}),
	]
	core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_1)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, commands_turn_2)
	var target_unit = battle_state.get_side("P2").get_active_unit()
	var apply_events := 0
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_APPLY and String(ev.payload_summary).find("mp_regen") != -1:
			apply_events += 1
	if apply_events != 1:
		fail("stacking=none rule_mod should emit exactly one apply log while the instance remains active")
		return
	var rule_mod_count := 0
	for rule_mod_instance in target_unit.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == "mp_regen":
			rule_mod_count += 1
	if rule_mod_count != 1:
		fail("stacking=none rule_mod should keep exactly one runtime instance after repeated apply")
		return

