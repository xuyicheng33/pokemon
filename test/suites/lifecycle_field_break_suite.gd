extends "res://test/support/gdunit_suite_bridge.gd"

const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")


func test_manual_switch_breaks_field_before_replacement_enter() -> void:
	_assert_legacy_result(_test_manual_switch_breaks_field_before_replacement_enter(_harness))

func test_faint_replace_breaks_field_before_replacement_enter() -> void:
	_assert_legacy_result(_test_faint_replace_breaks_field_before_replacement_enter(_harness))
func _test_manual_switch_breaks_field_before_replacement_enter(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	_configure_sample_focus_field_break_test(content_index, "test_manual_switch")

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 118)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_field_call",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sample_focus_field":
		return harness.fail_result("manual switch field break test should start with active sample_focus_field")
	var field_instance_id: String = battle_state.field_state.instance_id
	var enter_unit = battle_state.get_unit_by_public_id("P1-B")
	if enter_unit == null:
		return harness.fail_result("missing P1-B replacement unit")
	var log_start: int = core.service("battle_logger").event_log.size()

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SWITCH,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"target_public_id": "P1-B",
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
		return harness.fail_result("creator manual switch should break active field before replacement enter")
	var break_idx := -1
	var enter_idx := -1
	for i in range(log_start, core.service("battle_logger").event_log.size()):
		var ev = core.service("battle_logger").event_log[i]
		if break_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.source_instance_id == field_instance_id and ev.trigger_name == "field_break":
			break_idx = i
		if enter_idx == -1 and ev.event_type == EventTypesScript.STATE_ENTER and ev.target_instance_id == enter_unit.unit_instance_id:
			enter_idx = i
		if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.source_instance_id == field_instance_id and ev.trigger_name == "on_enter" and ev.target_instance_id == enter_unit.unit_instance_id:
			return harness.fail_result("replacement on_enter should not see a field already broken by creator manual switch")
	if break_idx == -1 or enter_idx == -1:
		return harness.fail_result("manual switch field break ordering logs missing")
	if break_idx >= enter_idx:
		return harness.fail_result("field_break must happen before replacement state:enter on manual switch")
	return harness.pass_result()

func _test_faint_replace_breaks_field_before_replacement_enter(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	_configure_sample_focus_field_break_test(content_index, "test_faint_replace")

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 119)
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_field_call",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	if battle_state.field_state == null or battle_state.field_state.field_def_id != "sample_focus_field":
		return harness.fail_result("faint replace field break test should start with active sample_focus_field")
	var field_instance_id: String = battle_state.field_state.instance_id
	var fainted_unit = battle_state.get_unit_by_public_id("P1-A")
	var enter_unit = battle_state.get_unit_by_public_id("P1-B")
	if fainted_unit == null or enter_unit == null:
		return harness.fail_result("missing faint replace units")
	fainted_unit.current_hp = 1
	var log_start: int = core.service("battle_logger").event_log.size()

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
		}),
		core.service("command_builder").build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
			"skill_id": "sample_strike",
		}),
	])
	if battle_state.field_state != null:
		return harness.fail_result("creator faint should break active field before forced replacement enter")
	var break_idx := -1
	var replace_idx := -1
	var enter_idx := -1
	for i in range(log_start, core.service("battle_logger").event_log.size()):
		var ev = core.service("battle_logger").event_log[i]
		if break_idx == -1 and ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.source_instance_id == field_instance_id and ev.trigger_name == "field_break":
			break_idx = i
		if replace_idx == -1 and ev.event_type == EventTypesScript.STATE_REPLACE and ev.target_instance_id == enter_unit.unit_instance_id:
			replace_idx = i
		if enter_idx == -1 and ev.event_type == EventTypesScript.STATE_ENTER and ev.target_instance_id == enter_unit.unit_instance_id:
			enter_idx = i
		if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and ev.source_instance_id == field_instance_id and ev.trigger_name == "on_enter" and ev.target_instance_id == enter_unit.unit_instance_id:
			return harness.fail_result("forced replacement on_enter should not inherit a field already broken in faint window")
	if break_idx == -1 or replace_idx == -1 or enter_idx == -1:
		return harness.fail_result("faint replace field break ordering logs missing")
	if break_idx >= replace_idx or break_idx >= enter_idx:
		return harness.fail_result("field_break must happen before replacement/enter in faint window")
	return harness.pass_result()

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
