extends "res://tests/support/gdunit_suite_bridge.gd"

const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()


func test_obito_shiwei_weishouyu_segment_order_contract() -> void:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var ultimate = content_index.skills.get("obito_shiwei_weishouyu", null)
	if ultimate == null:
		fail("missing obito ultimate definition")
		return
	if int(ultimate.power) != 0:
		fail("obito ultimate top-level power should stay at 0 because damage_segments carry the real damage")
		return
	if ultimate.damage_segments.size() != 2:
		fail("obito ultimate should define exactly 2 segment resources")
		return
	var dark_segment = ultimate.damage_segments[0]
	var light_segment = ultimate.damage_segments[1]
	if int(dark_segment.repeat_count) != 2 or int(dark_segment.power) != 12 or String(dark_segment.combat_type_id) != "dark":
		fail("obito ultimate first segment resource should be 2x dark power 12")
		return
	if int(light_segment.repeat_count) != 8 or int(light_segment.power) != 12 or String(light_segment.combat_type_id) != "light":
		fail("obito ultimate second segment resource should be 8x light power 12")
		return

func test_obito_shiwei_weishouyu_segment_damage_log_contract() -> void:
	var result = _run_shiwei_weishouyu_case(_harness, 1540)
	if not bool(result.get("ok", false)):
		fail(str(result.get("error", "obito ultimate segment log case failed")))
		return
	var damage_events: Array = result.get("damage_events", [])
	if damage_events.size() != 10:
		fail("obito ultimate should emit 10 damage events")
		return
	for segment_index in range(10):
		var expected_marker := "segment %d/10" % [segment_index + 1]
		if String(damage_events[segment_index].payload_summary).find(expected_marker) == -1:
			fail("obito ultimate damage log missing %s marker" % expected_marker)
			return
		var expected_mul := 0.5 if segment_index < 2 else 2.0
		if not is_equal_approx(float(damage_events[segment_index].type_effectiveness), expected_mul):
			fail("obito ultimate segment %d should have type_effectiveness=%s" % [segment_index + 1, var_to_str(expected_mul)])
			return

func test_obito_shiwei_weishouyu_mid_kill_stop_contract() -> void:
	var baseline_result = _run_shiwei_weishouyu_case(_harness, 1541, -1, false)
	if not bool(baseline_result.get("ok", false)):
		fail(str(baseline_result.get("error", "obito ultimate baseline case failed")))
		return
	var baseline_events: Array = baseline_result.get("damage_events", [])
	if baseline_events.size() < 2:
		fail("obito ultimate baseline case should expose at least 2 damage segments")
		return
	var lethal_hp := 0
	for segment_index in range(2):
		lethal_hp += abs(int(baseline_events[segment_index].value_changes[0].delta))
	lethal_hp -= 1
	if lethal_hp <= 0:
		fail("obito ultimate mid-kill case computed invalid lethal hp")
		return
	var kill_result = _run_shiwei_weishouyu_case(_harness, 1542, lethal_hp, false)
	if not bool(kill_result.get("ok", false)):
		fail(str(kill_result.get("error", "obito ultimate mid-kill case failed")))
		return
	var damage_events: Array = kill_result.get("damage_events", [])
	if damage_events.size() != 2:
		fail("obito ultimate should stop remaining segments immediately after target faints")
		return
	if int(kill_result.get("target_hp", -1)) != 0:
		fail("obito ultimate mid-kill case should still KO the target")
		return
	if String(damage_events[1].payload_summary).find("segment 2/10") == -1:
		fail("obito ultimate mid-kill case should stop on the lethal second segment")
		return


@warning_ignore("shadowed_global_identifier")
func _run_shiwei_weishouyu_case(harness, seed: int, target_hp_override: int = -1, use_mirror: bool = true) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return {"ok": false, "error": str(core_payload["error"])}
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return {"ok": false, "error": "SampleBattleFactory init failed"}
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_setup = _support.build_obito_mirror_setup(sample_factory) if use_mirror else _support.build_obito_setup(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, seed)
	var obito = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if obito == null or target == null:
		return {"ok": false, "error": "missing obito active units for ultimate case"}
	obito.ultimate_points = 3
	if target_hp_override > 0:
		target.current_hp = target_hp_override
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "obito_shiwei_weishouyu"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	return {
		"ok": true,
		"damage_events": _support.collect_actor_damage_events(core.service("battle_logger").event_log, "P1-A"),
		"target_hp": int(target.current_hp),
	}
