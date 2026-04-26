extends "res://tests/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const CombatTypeTestHelperScript := preload("res://tests/support/combat_type_test_helper.gd")

var _helper = CombatTypeTestHelperScript.new()


func test_combat_type_direct_damage_and_logs() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return

	var neutral_result = _run_direct_damage_case(_harness, core, sample_factory, "", null)
	if neutral_result.has("error"):
		fail(str(neutral_result["error"]))
		return
	if not is_equal_approx(float(neutral_result["type_effectiveness"]), 1.0):
		fail("neutral direct damage should log type_effectiveness = 1.0")
		return

	var typed_result = _run_direct_damage_case(_harness, core, sample_factory, "fire", null)
	if typed_result.has("error"):
		fail(str(typed_result["error"]))
		return
	if not is_equal_approx(float(typed_result["type_effectiveness"]), 2.0):
		fail("typed direct damage should log type_effectiveness = 2.0")
		return
	if int(typed_result["damage"]) <= int(neutral_result["damage"]):
		fail("typed direct damage should exceed neutral baseline")
		return

	var modded_result = _run_direct_damage_case(_harness, core, sample_factory, "fire", 1.5)
	if modded_result.has("error"):
		fail(str(modded_result["error"]))
		return
	if not is_equal_approx(float(modded_result["type_effectiveness"]), 2.0):
		fail("rule_mod case should still log raw type_effectiveness = 2.0")
		return
	if int(modded_result["damage"]) <= int(typed_result["damage"]):
		fail("rule_mod should stack on top of type effectiveness")
		return

func test_combat_type_formula_damage_paths() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return

	var inheritance_result = _run_formula_skill_case(_harness, core, sample_factory)
	if inheritance_result.has("error"):
		fail(str(inheritance_result["error"]))
		return
	if not is_equal_approx(float(inheritance_result["type_effectiveness"]), 2.0):
		fail("formula damage in skill chain should inherit skill combat_type")
		return

	var passive_result = _run_non_skill_formula_case(_harness, core, sample_factory)
	if passive_result.has("error"):
		fail(str(passive_result["error"]))
		return
	if not is_equal_approx(float(passive_result["type_effectiveness"]), 1.0):
		fail("non-skill formula damage should stay neutral")
		return

func test_combat_type_default_and_recoil_paths() -> void:
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
	var battle_setup = _harness.build_sample_setup(sample_factory)
	var battle_state = _build_initialized_battle(core, content_index, battle_setup, 641)

	var p1_active = battle_state.get_side("P1").get_active_unit()
	var p2_active = battle_state.get_side("P2").get_active_unit()
	p1_active.current_mp = 0
	p1_active.regen_per_turn = 0
	p2_active.current_mp = 0
	p2_active.regen_per_turn = 0
	for bench_unit_id in battle_state.get_side("P1").bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	for bench_unit_id in battle_state.get_side("P2").bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])

	var default_damage_found: bool = false
	var recoil_damage_found: bool = false
	for ev in core.service("battle_logger").event_log:
		if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(ev.payload_summary).find("dealt") != -1:
			if not is_equal_approx(float(ev.type_effectiveness), 1.0):
				fail("default action damage should log neutral type_effectiveness")
				return
			default_damage_found = true
		if String(ev.payload_summary).find("recoil") != -1:
			if not is_equal_approx(float(ev.type_effectiveness), 1.0):
				fail("recoil damage should log neutral type_effectiveness")
				return
			recoil_damage_found = true
	if not default_damage_found:
		fail("missing default action damage log")
		return
	if not recoil_damage_found:
		fail("missing recoil damage log")
		return

func test_recoil_ratio_runtime_config_contract() -> void:
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
	var format_config = content_index.battle_formats.get("prototype_full_open", null)
	if format_config == null:
		fail("missing sample battle format")
		return
	format_config.default_recoil_ratio = 0.5
	var battle_setup = _harness.build_sample_setup(sample_factory)
	var battle_state = _build_initialized_battle(core, content_index, battle_setup, 642)
	var p1_active = battle_state.get_side("P1").get_active_unit()
	var p2_active = battle_state.get_side("P2").get_active_unit()
	p1_active.current_mp = 0
	p1_active.regen_per_turn = 0
	p2_active.current_mp = 0
	p2_active.regen_per_turn = 0
	for bench_unit_id in battle_state.get_side("P1").bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	for bench_unit_id in battle_state.get_side("P2").bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null:
			bench_unit.current_hp = 0
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [])
	var actual_recoil: int = -1
	for ev in core.service("battle_logger").event_log:
		if ev.event_type != EventTypesScript.EFFECT_DAMAGE:
			continue
		if ev.target_instance_id != p1_active.unit_instance_id:
			continue
		if String(ev.payload_summary).find("recoil") == -1:
			continue
		if ev.value_changes.is_empty():
			fail("recoil log should carry hp value_change")
			return
		actual_recoil = abs(int(ev.value_changes[0].delta))
		break
	if actual_recoil < 0:
		fail("missing recoil damage log for configured-ratio default action")
		return
	var expected_recoil: int = max(1, int(floor(float(p1_active.max_hp) * 0.5)))
	if actual_recoil != expected_recoil:
		fail("default recoil should read runtime-configured ratio: expected=%d actual=%d" % [expected_recoil, actual_recoil])
		return


func _run_direct_damage_case(harness, core, sample_factory, skill_type_id: String, final_mod: Variant) -> Dictionary:
	return _helper.run_direct_damage_case(harness, core, sample_factory, skill_type_id, final_mod)

func _run_formula_skill_case(harness, core, sample_factory) -> Dictionary:
	return _helper.run_formula_skill_case(harness, core, sample_factory)

func _run_non_skill_formula_case(harness, core, sample_factory) -> Dictionary:
	return _helper.run_non_skill_formula_case(harness, core, sample_factory)

@warning_ignore("shadowed_global_identifier")
func _build_initialized_battle(core, content_index, battle_setup, seed: int):
	return _helper.build_initialized_battle(core, content_index, battle_setup, seed)
