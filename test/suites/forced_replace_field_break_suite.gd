extends "res://tests/support/gdunit_suite_bridge.gd"

const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

class TestReplacementSelector:
	extends "res://src/battle_core/lifecycle/replacement_selector.gd"

	var next_selection: Variant = null

	func select_replacement(_battle_state, _side_id: String, _legal_bench_ids: PackedStringArray, _reason: String, _chain_context):
		return next_selection


func test_forced_replace_breaks_field_before_replacement_enter() -> void:
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
	_configure_sample_focus_field_break_test(content_index, "test_forced_replace_break")
	if not content_index.units["sample_tidekit"].skill_ids.has("sample_field_call"):
		content_index.units["sample_tidekit"].skill_ids[0] = "sample_field_call"

	var forced_payload = ForcedReplacePayloadScript.new()
	forced_payload.payload_type = "forced_replace"
	forced_payload.scope = "target"
	forced_payload.selector_reason = "forced_replace"
	var forced_effect = EffectDefinitionScript.new()
	forced_effect.id = "test_forced_replace_break_effect"
	forced_effect.display_name = "Forced Replace Break Effect"
	forced_effect.scope = "target"
	forced_effect.trigger_names = PackedStringArray(["on_cast"])
	forced_effect.payloads.clear()
	forced_effect.payloads.append(forced_payload)
	content_index.register_resource(forced_effect)

	var forced_skill = SkillDefinitionScript.new()
	forced_skill.id = "test_forced_replace_break_skill"
	forced_skill.display_name = "Forced Replace Break Skill"
	forced_skill.damage_kind = "none"
	forced_skill.power = 0
	forced_skill.accuracy = 100
	forced_skill.mp_cost = 0
	forced_skill.priority = 0
	forced_skill.targeting = "enemy_active_slot"
	forced_skill.effects_on_cast_ids = PackedStringArray([forced_effect.id])
	content_index.register_resource(forced_skill)
	if not content_index.units["sample_pyron"].skill_ids.has(forced_skill.id):
		content_index.units["sample_pyron"].skill_ids[0] = forced_skill.id

	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 222)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	var selected_unit = battle_state.get_unit_by_public_id("P2-C")
	if p1_active == null or selected_unit == null:
		fail("forced_replace break test missing units")
		return
	p1_active.base_speed = 999
	var selector := TestReplacementSelector.new()
	selector.next_selection = selected_unit.unit_instance_id
	core.service("replacement_service").replacement_selector = selector

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_field_call",
		}),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sample_focus_field":
		fail("forced_replace break test should start with active sample_focus_field")
		return
	var field_instance_id: String = battle_state.field_state.instance_id
	var log_start: int = core.service("battle_logger").event_log.size()

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": forced_skill.id,
		}),
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if battle_state.field_state != null:
		fail("creator forced replace should break active field before replacement enter")
		return
	var break_idx := -1
	var replace_idx := -1
	var enter_idx := -1
	for i in range(log_start, core.service("battle_logger").event_log.size()):
		var ev = core.service("battle_logger").event_log[i]
		if break_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.source_instance_id == field_instance_id and ev.trigger_name == "field_break":
			break_idx = i
		if replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE and ev.target_instance_id == selected_unit.unit_instance_id:
			replace_idx = i
		if enter_idx == -1 and ev.event_type == EventTypesScript.STATE_ENTER and ev.target_instance_id == selected_unit.unit_instance_id:
			enter_idx = i
		if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.source_instance_id == field_instance_id and ev.trigger_name == "on_enter" and ev.target_instance_id == selected_unit.unit_instance_id:
			fail("forced replacement on_enter should not see a field already broken by creator exit")
			return
	if break_idx == -1 or replace_idx == -1 or enter_idx == -1:
		fail("forced_replace field break ordering logs missing")
		return
	if break_idx >= replace_idx or break_idx >= enter_idx:
		fail("field_break must happen before replacement/enter on forced_replace")
		return

func _configure_sample_focus_field_break_test(content_index, prefix: String) -> void:
	var field_enter_payload = StatModPayloadScript.new()
	field_enter_payload.payload_type = "stat_mod"
	field_enter_payload.stat_name = "speed"
	field_enter_payload.stage_delta = 1
	var field_enter_effect = EffectDefinitionScript.new()
	field_enter_effect.id = "%s_field_on_enter_effect" % prefix
	field_enter_effect.display_name = "%s Field On Enter" % prefix
	field_enter_effect.scope = "target"
	field_enter_effect.trigger_names = PackedStringArray(["field_apply"])
	field_enter_effect.payloads.clear()
	field_enter_effect.payloads.append(field_enter_payload)

	var field_break_payload = StatModPayloadScript.new()
	field_break_payload.payload_type = "stat_mod"
	field_break_payload.stat_name = "attack"
	field_break_payload.stage_delta = 1
	var field_break_effect = EffectDefinitionScript.new()
	field_break_effect.id = "%s_field_break_effect" % prefix
	field_break_effect.display_name = "%s Field Break" % prefix
	field_break_effect.scope = "target"
	field_break_effect.trigger_names = PackedStringArray(["field_break"])
	field_break_effect.payloads.clear()
	field_break_effect.payloads.append(field_break_payload)

	content_index.register_resource(field_enter_effect)
	content_index.register_resource(field_break_effect)
	var focus_field = content_index.fields["sample_focus_field"]
	focus_field.effect_ids = PackedStringArray([field_enter_effect.id])
	focus_field.on_break_effect_ids = PackedStringArray([field_break_effect.id])
