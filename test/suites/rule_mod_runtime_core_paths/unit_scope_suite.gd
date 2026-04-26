extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")


func test_rule_mod_paths() -> void:
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
	var battle_state = _harness.build_initialized_battle(core, content_index, sample_factory, 104)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	var p1_before_mp: int = p1_active.current_mp

	var deny_payload = RuleModPayloadScript.new()
	deny_payload.payload_type = "rule_mod"
	deny_payload.mod_kind = "action_legality"
	deny_payload.mod_op = "deny"
	deny_payload.value = "sample_strike"
	deny_payload.scope = "self"
	deny_payload.duration_mode = "turns"
	deny_payload.duration = 2
	deny_payload.decrement_on = "turn_start"
	deny_payload.stacking = "replace"
	deny_payload.priority = 10
	if core.service("rule_mod_service").create_instance(deny_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_deny", 0, p1_active.base_speed) == null:
		fail("failed to create action_legality rule_mod")
		return

	var regen_payload = RuleModPayloadScript.new()
	regen_payload.payload_type = "rule_mod"
	regen_payload.mod_kind = "mp_regen"
	regen_payload.mod_op = "set"
	regen_payload.value = 0
	regen_payload.scope = "self"
	regen_payload.duration_mode = "turns"
	regen_payload.duration = 1
	regen_payload.decrement_on = "turn_start"
	regen_payload.stacking = "replace"
	regen_payload.priority = 10
	if core.service("rule_mod_service").create_instance(regen_payload, {"scope": "unit", "id": p1_active.unit_instance_id}, battle_state, "test_rule_mod_regen", 0, p1_active.base_speed) == null:
		fail("failed to create mp_regen rule_mod")
		return

	var legal_action_set = core.service("legal_action_service").get_legal_actions(battle_state, "P1", content_index)
	if legal_action_set.legal_skill_ids.has("sample_strike"):
		fail("action_legality rule_mod did not block sample_strike")
		return

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	if p1_active.current_mp != p1_before_mp:
		fail("mp_regen rule_mod did not override turn_start regen")
		return
	var has_remove_log := false
	for ev in core.service("battle_logger").event_log:
		if ev.event_type == EventTypesScript.EFFECT_RULE_MOD_REMOVE and ev.target_instance_id == p1_active.unit_instance_id:
			has_remove_log = true
			break
	if not has_remove_log:
		fail("rule_mod remove event missing")
		return

	var baseline_state = _harness.build_initialized_battle(core, content_index, sample_factory, 105)
	var modded_state = _harness.build_initialized_battle(core, content_index, sample_factory, 105)
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
	var baseline_damage = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")

	var final_mod_payload = RuleModPayloadScript.new()
	final_mod_payload.payload_type = "rule_mod"
	final_mod_payload.mod_kind = "final_mod"
	final_mod_payload.mod_op = "mul"
	final_mod_payload.value = 2.0
	final_mod_payload.scope = "self"
	final_mod_payload.duration_mode = "turns"
	final_mod_payload.duration = 2
	final_mod_payload.decrement_on = "turn_end"
	final_mod_payload.stacking = "replace"
	final_mod_payload.priority = 10
	var modded_p1_active = modded_state.get_side("P1").get_active_unit()
	if core.service("rule_mod_service").create_instance(final_mod_payload, {"scope": "unit", "id": modded_p1_active.unit_instance_id}, modded_state, "test_rule_mod_final", 0, modded_p1_active.base_speed) == null:
		fail("failed to create final_mod rule_mod")
		return
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(modded_state, content_index, baseline_commands)
	var modded_damage = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A")
	if baseline_damage <= 0 or modded_damage <= baseline_damage:
		fail("final_mod rule_mod did not increase damage")
		return
