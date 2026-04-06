extends RefCounted

const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("rule_mod_field_scope_paths", failures, Callable(self, "_test_rule_mod_field_scope_paths").bind(harness))

func _test_rule_mod_field_scope_paths(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)

	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, 115)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	var p2_active = battle_state.get_side("P2").get_active_unit()
	p1_active.regen_per_turn = 0
	p2_active.regen_per_turn = 0
	p1_active.current_mp = 0
	p2_active.current_mp = 0

	var field_regen_payload = RuleModPayloadScript.new()
	field_regen_payload.payload_type = "rule_mod"
	field_regen_payload.mod_kind = "mp_regen"
	field_regen_payload.mod_op = "add"
	field_regen_payload.value = 5
	field_regen_payload.scope = "field"
	field_regen_payload.duration_mode = "turns"
	field_regen_payload.duration = 2
	field_regen_payload.decrement_on = "turn_start"
	field_regen_payload.stacking = "replace"
	field_regen_payload.priority = 5
	if core.service("rule_mod_service").create_instance(field_regen_payload, {"scope": "field", "id": "field"}, battle_state, "test_field_regen_mod", 0, 0) == null:
		return harness.fail_result("failed to create field-scope mp_regen rule_mod")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if p1_active.current_mp != 5 or p2_active.current_mp != 5:
		return harness.fail_result("field-scope mp_regen rule_mod did not apply to both active units")
	var has_field_remove_log := false
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == "field":
			has_field_remove_log = true
			break
	if not has_field_remove_log:
		return harness.fail_result("field-scope rule_mod remove event missing")

	var baseline_state = harness.build_initialized_battle(core, content_index, sample_factory, 116)
	var modded_state = harness.build_initialized_battle(core, content_index, sample_factory, 116)
	var baseline_commands: Array = [
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
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(baseline_state, content_index, baseline_commands)
	var baseline_damage = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	var field_final_mod_payload = RuleModPayloadScript.new()
	field_final_mod_payload.payload_type = "rule_mod"
	field_final_mod_payload.mod_kind = "final_mod"
	field_final_mod_payload.mod_op = "mul"
	field_final_mod_payload.value = 2.0
	field_final_mod_payload.scope = "field"
	field_final_mod_payload.duration_mode = "turns"
	field_final_mod_payload.duration = 2
	field_final_mod_payload.decrement_on = "turn_end"
	field_final_mod_payload.stacking = "replace"
	field_final_mod_payload.priority = 10
	if core.service("rule_mod_service").create_instance(field_final_mod_payload, {"scope": "field", "id": "field"}, modded_state, "test_field_final_mod", 0, 0) == null:
		return harness.fail_result("failed to create field-scope final_mod rule_mod")
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(modded_state, content_index, baseline_commands)
	var modded_damage = harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if baseline_damage <= 0 or modded_damage <= baseline_damage:
		return harness.fail_result("field-scope final_mod rule_mod did not increase damage")

	var legality_state = harness.build_initialized_battle(core, content_index, sample_factory, 117)
	var field_legality_payload = RuleModPayloadScript.new()
	field_legality_payload.payload_type = "rule_mod"
	field_legality_payload.mod_kind = "action_legality"
	field_legality_payload.mod_op = "deny"
	field_legality_payload.value = "sample_strike"
	field_legality_payload.scope = "field"
	field_legality_payload.duration_mode = "turns"
	field_legality_payload.duration = 2
	field_legality_payload.decrement_on = "turn_start"
	field_legality_payload.stacking = "replace"
	field_legality_payload.priority = 10
	if core.service("rule_mod_service").create_instance(field_legality_payload, {"scope": "field", "id": "field"}, legality_state, "test_field_action_legality", 0, 0) == null:
		return harness.fail_result("failed to create field-scope action_legality rule_mod")
	var legal_action_set = core.service("legal_action_service").get_legal_actions(legality_state, "P1", content_index)
	if legal_action_set.legal_skill_ids.has("sample_strike"):
		return harness.fail_result("field-scope action_legality rule_mod did not block sample_strike")

	var invalid_scope_payload = RuleModPayloadScript.new()
	invalid_scope_payload.payload_type = "rule_mod"
	invalid_scope_payload.mod_kind = "final_mod"
	invalid_scope_payload.mod_op = "mul"
	invalid_scope_payload.value = 1.1
	invalid_scope_payload.scope = "field"
	invalid_scope_payload.duration_mode = "turns"
	invalid_scope_payload.duration = 1
	invalid_scope_payload.decrement_on = "turn_start"
	invalid_scope_payload.stacking = "replace"
	var invalid_owner = legality_state.get_side("P1").get_active_unit()
	if core.service("rule_mod_service").create_instance(invalid_scope_payload, {"scope": "unit", "id": invalid_owner.unit_instance_id}, legality_state, "test_invalid_field_owner", 0, invalid_owner.base_speed) != null:
		return harness.fail_result("invalid field owner binding should fail")
	if core.service("rule_mod_service").last_error_code != ErrorCodesScript.INVALID_RULE_MOD_DEFINITION:
		return harness.fail_result("invalid field owner binding should return invalid_rule_mod_definition")
	return harness.pass_result()
