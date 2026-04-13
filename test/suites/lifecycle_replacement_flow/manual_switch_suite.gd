extends "res://test/suites/lifecycle_replacement_flow/base.gd"



func test_manual_switch_lifecycle_chain() -> void:
	_assert_legacy_result(_test_manual_switch_lifecycle_chain(_harness))
func _test_manual_switch_lifecycle_chain(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var switch_payload = StatModPayloadScript.new()
	switch_payload.payload_type = "stat_mod"
	switch_payload.stat_name = "attack"
	switch_payload.stage_delta = 1
	var switch_effect = EffectDefinitionScript.new()
	switch_effect.id = "test_manual_switch_on_switch_effect"
	switch_effect.display_name = "Manual Switch On Switch"
	switch_effect.scope = "self"
	switch_effect.trigger_names = PackedStringArray(["on_switch"])
	switch_effect.payloads.clear()
	switch_effect.payloads.append(switch_payload)
	var switch_passive = PassiveSkillDefinitionScript.new()
	switch_passive.id = "test_manual_switch_on_switch_passive"
	switch_passive.display_name = "Manual Switch On Switch Passive"
	switch_passive.trigger_names = PackedStringArray(["on_switch"])
	switch_passive.effect_ids = PackedStringArray([switch_effect.id])
	content_index.register_resource(switch_effect)
	content_index.register_resource(switch_passive)

	var exit_payload = StatModPayloadScript.new()
	exit_payload.payload_type = "stat_mod"
	exit_payload.stat_name = "defense"
	exit_payload.stage_delta = 1
	var exit_effect = EffectDefinitionScript.new()
	exit_effect.id = "test_manual_switch_on_exit_effect"
	exit_effect.display_name = "Manual Switch On Exit"
	exit_effect.scope = "self"
	exit_effect.trigger_names = PackedStringArray(["on_exit"])
	exit_effect.payloads.clear()
	exit_effect.payloads.append(exit_payload)
	var exit_item = PassiveItemDefinitionScript.new()
	exit_item.id = "test_manual_switch_on_exit_item"
	exit_item.display_name = "Manual Switch On Exit Item"
	exit_item.trigger_names = PackedStringArray(["on_exit"])
	exit_item.effect_ids = PackedStringArray([exit_effect.id])
	content_index.register_resource(exit_effect)
	content_index.register_resource(exit_item)

	var enter_payload = StatModPayloadScript.new()
	enter_payload.payload_type = "stat_mod"
	enter_payload.stat_name = "speed"
	enter_payload.stage_delta = 1
	var enter_effect = EffectDefinitionScript.new()
	enter_effect.id = "test_manual_switch_on_enter_effect"
	enter_effect.display_name = "Manual Switch On Enter"
	enter_effect.scope = "self"
	enter_effect.trigger_names = PackedStringArray(["on_enter"])
	enter_effect.payloads.clear()
	enter_effect.payloads.append(enter_payload)
	var enter_passive = PassiveSkillDefinitionScript.new()
	enter_passive.id = "test_manual_switch_on_enter_passive"
	enter_passive.display_name = "Manual Switch On Enter Passive"
	enter_passive.trigger_names = PackedStringArray(["on_enter"])
	enter_passive.effect_ids = PackedStringArray([enter_effect.id])
	content_index.register_resource(enter_effect)
	content_index.register_resource(enter_passive)

	content_index.units["sample_pyron"].passive_skill_id = switch_passive.id
	content_index.units["sample_pyron"].passive_item_id = exit_item.id
	content_index.units["sample_mossaur"].passive_skill_id = enter_passive.id

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 108)
	var commands: Array = [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SWITCH,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"target_public_id": "P1-B",
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

	var switch_idx := -1
	var on_switch_effect_idx := -1
	var on_exit_effect_idx := -1
	var state_exit_idx := -1
	var state_replace_idx := -1
	var state_enter_idx := -1
	var on_enter_effect_idx := -1
	var enter_unit = battle_state.get_unit_by_public_id("P1-B")
	for i in range(core.service("battle_logger").event_log.size()):
		var ev = core.service("battle_logger").event_log[i]
		if switch_idx == -1 and ev.event_type == EventTypesScript.STATE_SWITCH:
			switch_idx = i
		if on_switch_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
			on_switch_effect_idx = i
		if on_exit_effect_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_item:"):
			on_exit_effect_idx = i
		if state_exit_idx == -1 and ev.event_type == EventTypesScript.STATE_EXIT:
			state_exit_idx = i
		if state_replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE and enter_unit != null and ev.target_instance_id == enter_unit.unit_instance_id:
			state_replace_idx = i
		if state_enter_idx == -1 and ev.event_type == EventTypesScript.STATE_ENTER and enter_unit != null and ev.target_instance_id == enter_unit.unit_instance_id:
			state_enter_idx = i
		if on_enter_effect_idx == -1 and state_enter_idx != -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:") and i > state_enter_idx:
			on_enter_effect_idx = i
	if switch_idx == -1 or on_switch_effect_idx == -1 or on_exit_effect_idx == -1 or state_exit_idx == -1 or state_replace_idx == -1 or state_enter_idx == -1 or on_enter_effect_idx == -1:
		return harness.fail_result("missing manual switch lifecycle events")
	if enter_unit == null:
		return harness.fail_result("missing manual switch replacement unit")
	if enter_unit.reentered_turn_index != 1:
		return harness.fail_result("manual switch entered unit should stamp current turn as reentered_turn_index")
	if enter_unit.has_acted:
		return harness.fail_result("manual switch entered unit should reset has_acted=false")
	if enter_unit.action_window_passed:
		return harness.fail_result("manual switch entered unit should reset action_window_passed=false")
	if not (switch_idx < on_switch_effect_idx and on_switch_effect_idx < on_exit_effect_idx and on_exit_effect_idx < state_exit_idx and state_exit_idx < state_replace_idx and state_replace_idx < state_enter_idx and state_enter_idx < on_enter_effect_idx):
		return harness.fail_result("manual switch lifecycle ordering mismatch (%d,%d,%d,%d,%d,%d,%d)" % [switch_idx, on_switch_effect_idx, on_exit_effect_idx, state_exit_idx, state_replace_idx, state_enter_idx, on_enter_effect_idx])
	return harness.pass_result()
