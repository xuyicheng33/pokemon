extends "res://test/suites/lifecycle_replacement_flow/base.gd"



func test_lifecycle_faint_replace_chain() -> void:
	_assert_legacy_result(_test_lifecycle_faint_replace_chain(_harness))
func _test_lifecycle_faint_replace_chain(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var kill_payload = StatModPayloadScript.new()
	kill_payload.payload_type = "stat_mod"
	kill_payload.stat_name = "attack"
	kill_payload.stage_delta = 1
	var kill_effect = EffectDefinitionScript.new()
	kill_effect.id = "test_on_kill_buff_effect"
	kill_effect.display_name = "On Kill Buff"
	kill_effect.scope = "self"
	kill_effect.trigger_names = PackedStringArray(["on_kill"])
	kill_effect.payloads.clear()
	kill_effect.payloads.append(kill_payload)
	var kill_passive = PassiveSkillDefinitionScript.new()
	kill_passive.id = "test_on_kill_passive"
	kill_passive.display_name = "On Kill Passive"
	kill_passive.trigger_names = PackedStringArray(["on_kill"])
	kill_passive.effect_ids = PackedStringArray([kill_effect.id])
	content_index.register_resource(kill_effect)
	content_index.register_resource(kill_passive)
	content_index.units["sample_pyron"].passive_skill_id = kill_passive.id

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 103)
	var p2_active = battle_state.get_side("P2").get_active_unit()
	p2_active.current_hp = 1
	var commands: Array = [
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
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
	]
	core.service("turn_loop_controller").run_turn(battle_state, content_index, commands)

	var faint_idx := -1
	var kill_effect_idx := -1
	var exit_idx := -1
	var replace_idx := -1
	var enter_idx := -1
	for i in range(core.service("battle_logger").event_log.size()):
		var ev = core.service("battle_logger").event_log[i]
		if faint_idx == -1 and ev.event_type == EventTypesScript.STATE_FAINT:
			faint_idx = i
		if kill_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
			kill_effect_idx = i
		if exit_idx == -1 and ev.event_type == EventTypesScript.STATE_EXIT:
			exit_idx = i
		if replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE:
			replace_idx = i
		if ev.event_type == EventTypesScript.STATE_ENTER and i > replace_idx and replace_idx != -1:
			enter_idx = i
			break
	if faint_idx == -1 or exit_idx == -1 or replace_idx == -1 or enter_idx == -1:
		return harness.fail_result("missing lifecycle events in faint window")
	if kill_effect_idx == -1:
		return harness.fail_result("on_kill trigger effect missing")
	if not (faint_idx < kill_effect_idx and kill_effect_idx < exit_idx and exit_idx < replace_idx and replace_idx < enter_idx):
		return harness.fail_result("faint lifecycle ordering mismatch")
	return harness.pass_result()
