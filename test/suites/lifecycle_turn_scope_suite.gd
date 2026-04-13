extends "res://test/support/gdunit_suite_bridge.gd"

const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")


func test_turn_scope_active_and_field() -> void:
	_assert_legacy_result(_test_turn_scope_active_and_field(_harness))
func _test_turn_scope_active_and_field(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var turn_payload = StatModPayloadScript.new()
	turn_payload.payload_type = "stat_mod"
	turn_payload.stat_name = "speed"
	turn_payload.stage_delta = 1
	var turn_effect = EffectDefinitionScript.new()
	turn_effect.id = "test_turn_start_stat_mod"
	turn_effect.display_name = "Test Turn Start Stat Mod"
	turn_effect.scope = "self"
	turn_effect.trigger_names = PackedStringArray(["turn_start"])
	turn_effect.payloads.clear()
	turn_effect.payloads.append(turn_payload)
	var turn_passive = PassiveSkillDefinitionScript.new()
	turn_passive.id = "test_passive_turn_start"
	turn_passive.display_name = "Test Passive Turn Start"
	turn_passive.trigger_names = PackedStringArray(["turn_start"])
	turn_passive.effect_ids = PackedStringArray([turn_effect.id])
	content_index.register_resource(turn_effect)
	content_index.register_resource(turn_passive)
	content_index.units["sample_pyron"].passive_skill_id = turn_passive.id
	content_index.units["sample_mossaur"].passive_skill_id = turn_passive.id
	content_index.units["sample_tidekit"].passive_skill_id = turn_passive.id

	var field_payload = ResourceModPayloadScript.new()
	field_payload.payload_type = "resource_mod"
	field_payload.resource_key = "mp"
	field_payload.amount = 2
	var field_effect = EffectDefinitionScript.new()
	field_effect.id = "test_field_turn_start_effect"
	field_effect.display_name = "Test Field Turn Start Effect"
	field_effect.scope = "self"
	field_effect.trigger_names = PackedStringArray(["turn_start"])
	field_effect.payloads.clear()
	field_effect.payloads.append(field_payload)
	var field_def = FieldDefinitionScript.new()
	field_def.id = "test_turn_scope_field"
	field_def.display_name = "Turn Scope Field"
	field_def.effect_ids = PackedStringArray([field_effect.id])
	content_index.register_resource(field_effect)
	content_index.register_resource(field_def)

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 102)
	var bench_ids: Array = []
	for side_state in battle_state.sides:
		for bench_unit_id in side_state.bench_order:
			bench_ids.append(bench_unit_id)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	p1_active.current_mp = 10
	p1_active.regen_per_turn = 0
	var field_state = FieldStateScript.new()
	field_state.field_def_id = field_def.id
	field_state.instance_id = "test_field_instance"
	field_state.creator = p1_active.unit_instance_id
	field_state.remaining_turns = 2
	field_state.source_kind_order = 1
	field_state.source_order_speed_snapshot = p1_active.base_speed
	battle_state.field_state = field_state

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	var passive_event_count: int = 0
	var field_event_count: int = 0
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_STAT_MOD and str(ev.source_instance_id).begins_with("passive_skill:"):
			passive_event_count += 1
			if bench_ids.has(ev.target_instance_id):
				return harness.fail_result("bench unit triggered turn_start passive")
		if ev.event_type == EventTypesScript.EFFECT_RESOURCE_MOD and ev.source_instance_id == "test_field_instance":
			field_event_count += 1
	if passive_event_count != 2:
		return harness.fail_result("turn_start passive should trigger exactly for active units")
	if field_event_count < 1:
		return harness.fail_result("field turn_start effect missing")
	return harness.pass_result()
