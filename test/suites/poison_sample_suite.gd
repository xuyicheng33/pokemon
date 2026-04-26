extends "res://tests/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")


func test_poison_sample_fixed_damage_type_effectiveness_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return

	var content_index_a = _harness.build_loaded_content_index(sample_factory)
	if content_index_a.skills.get("sample_poison_sting", null) == null:
		fail("missing sample_poison_sting skill content")
		return
	if content_index_a.effects.get("sample_poison_sting_burst", null) == null:
		fail("missing sample_poison_sting_burst effect content")
		return
	content_index_a.units["sample_pyron"].skill_ids[0] = "sample_poison_sting"
	var state_a = _harness.build_initialized_battle(core, content_index_a, sample_factory, 3101, _harness.build_sample_setup(sample_factory))
	var attacker_a = state_a.get_side("P1").get_active_unit()
	var target_a = state_a.get_side("P2").get_active_unit()
	if attacker_a == null or target_a == null:
		fail("missing active units for poison sample case A")
		return
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(state_a, content_index_a, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_poison_sting",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var expected_mul_a: float = core.service("combat_type_service").calc_effectiveness("poison", target_a.combat_type_ids)
	if not is_equal_approx(expected_mul_a, 2.0):
		fail("poison -> water baseline should be 2.0, got %s" % var_to_str(expected_mul_a))
		return
	var expected_damage_a: int = core.service("damage_service").apply_final_mod(15, expected_mul_a)
	var actual_damage_a: Dictionary = _extract_single_poison_burst_damage(core.service("battle_logger").event_log, target_a.unit_instance_id)
	if actual_damage_a.has("error"):
		fail(str(actual_damage_a["error"]))
		return
	if not is_equal_approx(float(actual_damage_a["type_effectiveness"]), expected_mul_a):
		fail("poison sample type_effectiveness mismatch: expected=%s actual=%s" % [
			var_to_str(expected_mul_a),
			var_to_str(actual_damage_a["type_effectiveness"]),
		])
		return
	if int(actual_damage_a["damage"]) != expected_damage_a:
		fail("poison sample damage mismatch (water): expected=%d actual=%d" % [
			expected_damage_a,
			int(actual_damage_a["damage"]),
		])
		return

	var content_index_b = _harness.build_loaded_content_index(sample_factory)
	content_index_b.units["sample_pyron"].skill_ids[0] = "sample_poison_sting"
	content_index_b.units["sample_tidekit"].combat_type_ids = PackedStringArray(["steel"])
	var state_b = _harness.build_initialized_battle(core, content_index_b, sample_factory, 3102, _harness.build_sample_setup(sample_factory))
	var target_b = state_b.get_side("P2").get_active_unit()
	if target_b == null:
		fail("missing target unit for poison sample case B")
		return
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(state_b, content_index_b, [
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.SKILL,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sample_poison_sting",
		}),
		core.service("command_builder").build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.WAIT,
			"command_source": "manual",
			"side_id": "P2",
			"actor_public_id": "P2-A",
		}),
	])
	var expected_mul_b: float = core.service("combat_type_service").calc_effectiveness("poison", target_b.combat_type_ids)
	if not is_equal_approx(expected_mul_b, 0.5):
		fail("poison -> steel baseline should be 0.5, got %s" % var_to_str(expected_mul_b))
		return
	var expected_damage_b: int = core.service("damage_service").apply_final_mod(15, expected_mul_b)
	var actual_damage_b: Dictionary = _extract_single_poison_burst_damage(core.service("battle_logger").event_log, target_b.unit_instance_id)
	if actual_damage_b.has("error"):
		fail(str(actual_damage_b["error"]))
		return
	if not is_equal_approx(float(actual_damage_b["type_effectiveness"]), expected_mul_b):
		fail("poison sample type_effectiveness mismatch (steel): expected=%s actual=%s" % [
			var_to_str(expected_mul_b),
			var_to_str(actual_damage_b["type_effectiveness"]),
		])
		return
	if int(actual_damage_b["damage"]) != expected_damage_b:
		fail("poison sample damage mismatch (steel): expected=%d actual=%d" % [
			expected_damage_b,
			int(actual_damage_b["damage"]),
		])
		return

func _extract_single_poison_burst_damage(event_log: Array, target_unit_id: String) -> Dictionary:
	var matched: Array = []
	for ev in event_log:
		if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(ev.target_instance_id) != String(target_unit_id):
			continue
		if String(ev.trigger_name) != "on_hit":
			continue
		if String(ev.payload_summary).find("damage") == -1:
			continue
		if ev.value_changes.is_empty():
			continue
		matched.append(ev)
	if matched.size() != 1:
		return {"error": "expected exactly one poison burst EFFECT_DAMAGE, got %d" % matched.size()}
	var ev = matched[0]
	return {
		"damage": abs(int(ev.value_changes[0].delta)),
		"type_effectiveness": float(ev.type_effectiveness),
	}

