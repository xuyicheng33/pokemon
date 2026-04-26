extends "res://tests/support/gdunit_suite_bridge.gd"

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class TestReplacementSelector:
	extends "res://src/battle_core/lifecycle/replacement_selector.gd"

	var next_selection: Variant = null

	func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
		return next_selection

@warning_ignore("shadowed_global_identifier")
func _run_manual_switch_replacement_trace(harness, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"failure": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"failure": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	_register_replacement_trace_content(content_index, "manual", "sample_pyron", "sample_mossaur")
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, seed)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
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
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var entered_unit = battle_state.get_unit_by_public_id("P1-B")
	return {
		"sequence": _collect_replacement_trace_sequence(core.service("battle_logger").event_log, entered_unit.unit_instance_id if entered_unit != null else ""),
		"entered_unit": entered_unit,
		"reentry_turn_index": 1,
	}

@warning_ignore("shadowed_global_identifier")
func _run_forced_replace_replacement_trace(harness, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"failure": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"failure": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	_register_replacement_trace_content(content_index, "forced", "sample_tidekit", "sample_mossaur")

	var forced_payload = EffectDefinitionScript.new()
	forced_payload.id = "trace_forced_replace_effect"
	forced_payload.display_name = "Trace Forced Replace"
	forced_payload.scope = "target"
	forced_payload.trigger_names = PackedStringArray(["on_cast"])
	var forced_replace_payload = ForcedReplacePayloadScript.new()
	forced_replace_payload.payload_type = "forced_replace"
	forced_replace_payload.scope = "target"
	forced_replace_payload.selector_reason = "forced_replace"
	forced_payload.payloads.clear()
	forced_payload.payloads.append(forced_replace_payload)
	content_index.register_resource(forced_payload)

	var forced_skill = SkillDefinitionScript.new()
	forced_skill.id = "trace_forced_replace_skill"
	forced_skill.display_name = "Trace Forced Replace Skill"
	forced_skill.damage_kind = "none"
	forced_skill.power = 0
	forced_skill.accuracy = 100
	forced_skill.mp_cost = 0
	forced_skill.priority = 0
	forced_skill.targeting = "enemy_active_slot"
	forced_skill.effects_on_cast_ids = PackedStringArray([forced_payload.id])
	content_index.register_resource(forced_skill)
	content_index.units["sample_pyron"].skill_ids[0] = forced_skill.id

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, seed)
	var selected_unit = battle_state.get_unit_by_public_id("P2-C")
	if selected_unit == null:
		return {"failure": "missing forced replacement unit"}
	var selector := TestReplacementSelector.new()
	selector.next_selection = selected_unit.unit_instance_id
	core.service("replacement_service").replacement_selector = selector

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": forced_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	return {
		"sequence": _collect_replacement_trace_sequence(core.service("battle_logger").event_log, selected_unit.unit_instance_id),
		"entered_unit": selected_unit,
		"reentry_turn_index": 1,
	}

func _register_replacement_trace_content(content_index, prefix: String, leaving_definition_id: String, entering_definition_id: String) -> void:
	var switch_payload = StatModPayloadScript.new()
	switch_payload.payload_type = "stat_mod"
	switch_payload.stat_name = "attack"
	switch_payload.stage_delta = 1
	var switch_effect = EffectDefinitionScript.new()
	switch_effect.id = "%s_trace_on_switch_effect" % prefix
	switch_effect.display_name = "%s Trace On Switch" % prefix
	switch_effect.scope = "self"
	switch_effect.trigger_names = PackedStringArray(["on_switch"])
	switch_effect.payloads.clear()
	switch_effect.payloads.append(switch_payload)
	var switch_passive = PassiveSkillDefinitionScript.new()
	switch_passive.id = "%s_trace_on_switch_passive" % prefix
	switch_passive.display_name = "%s Trace On Switch Passive" % prefix
	switch_passive.trigger_names = PackedStringArray(["on_switch"])
	switch_passive.effect_ids = PackedStringArray([switch_effect.id])
	content_index.register_resource(switch_effect)
	content_index.register_resource(switch_passive)

	var exit_payload = StatModPayloadScript.new()
	exit_payload.payload_type = "stat_mod"
	exit_payload.stat_name = "defense"
	exit_payload.stage_delta = 1
	var exit_effect = EffectDefinitionScript.new()
	exit_effect.id = "%s_trace_on_exit_effect" % prefix
	exit_effect.display_name = "%s Trace On Exit" % prefix
	exit_effect.scope = "self"
	exit_effect.trigger_names = PackedStringArray(["on_exit"])
	exit_effect.payloads.clear()
	exit_effect.payloads.append(exit_payload)
	var exit_item = PassiveItemDefinitionScript.new()
	exit_item.id = "%s_trace_on_exit_item" % prefix
	exit_item.display_name = "%s Trace On Exit Item" % prefix
	exit_item.trigger_names = PackedStringArray(["on_exit"])
	exit_item.effect_ids = PackedStringArray([exit_effect.id])
	content_index.register_resource(exit_effect)
	content_index.register_resource(exit_item)

	var enter_payload = StatModPayloadScript.new()
	enter_payload.payload_type = "stat_mod"
	enter_payload.stat_name = "speed"
	enter_payload.stage_delta = 1
	var enter_effect = EffectDefinitionScript.new()
	enter_effect.id = "%s_trace_on_enter_effect" % prefix
	enter_effect.display_name = "%s Trace On Enter" % prefix
	enter_effect.scope = "self"
	enter_effect.trigger_names = PackedStringArray(["on_enter"])
	enter_effect.payloads.clear()
	enter_effect.payloads.append(enter_payload)
	var enter_passive = PassiveSkillDefinitionScript.new()
	enter_passive.id = "%s_trace_on_enter_passive" % prefix
	enter_passive.display_name = "%s Trace On Enter Passive" % prefix
	enter_passive.trigger_names = PackedStringArray(["on_enter"])
	enter_passive.effect_ids = PackedStringArray([enter_effect.id])
	content_index.register_resource(enter_effect)
	content_index.register_resource(enter_passive)

	content_index.units[leaving_definition_id].passive_skill_id = switch_passive.id
	content_index.units[leaving_definition_id].passive_item_id = exit_item.id
	content_index.units[entering_definition_id].passive_skill_id = enter_passive.id

func _collect_replacement_trace_sequence(event_log: Array, entered_unit_id: String) -> Array:
	var sequence: Array = []
	for event in event_log:
		if String(event.event_type) == EventTypesScript.STATE_SWITCH:
			sequence.append("state_switch")
		elif String(event.event_type) == EventTypesScript.EFFECT_STAT_MOD and String(event.trigger_name) == "on_switch":
			sequence.append("effect_on_switch")
		elif String(event.event_type) == EventTypesScript.EFFECT_STAT_MOD and String(event.trigger_name) == "on_exit":
			sequence.append("effect_on_exit")
		elif String(event.event_type) == EventTypesScript.STATE_EXIT:
			sequence.append("state_exit")
		elif String(event.event_type) == EventTypesScript.STATE_REPLACE and String(event.target_instance_id) == entered_unit_id:
			sequence.append("state_replace")
		elif String(event.event_type) == EventTypesScript.STATE_ENTER and String(event.target_instance_id) == entered_unit_id:
			sequence.append("state_enter")
		elif String(event.event_type) == EventTypesScript.EFFECT_STAT_MOD and String(event.trigger_name) == "on_enter" and String(event.target_instance_id) == entered_unit_id:
			sequence.append("effect_on_enter")
	return sequence
