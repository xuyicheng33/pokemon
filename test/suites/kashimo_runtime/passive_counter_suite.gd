extends "res://test/suites/kashimo_runtime/base.gd"

func test_kashimo_thunder_resist_contract() -> void:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		fail(str(core_payload["error"]))
		return
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		fail("SampleBattleFactory init failed")
		return

	var baseline_content = _harness.build_loaded_content_index(sample_factory)
	var thunder_skill = SkillDefinitionScript.new()
	thunder_skill.id = "test_kashimo_incoming_thunder"
	thunder_skill.display_name = "Incoming Thunder"
	thunder_skill.damage_kind = "special"
	thunder_skill.power = 50
	thunder_skill.accuracy = 100
	thunder_skill.mp_cost = 0
	thunder_skill.priority = 0
	thunder_skill.targeting = "enemy_active_slot"
	thunder_skill.combat_type_id = "thunder"
	baseline_content.register_resource(thunder_skill)
	baseline_content.units["sample_tidekit"].skill_ids[0] = thunder_skill.id
	baseline_content.units["kashimo_hajime"].passive_skill_id = ""
	var baseline_state = _support.build_battle_state(core, baseline_content, _support.build_kashimo_setup(sample_factory), 806)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(baseline_state, baseline_content, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", thunder_skill.id),
	])
	var baseline_damage: int = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P2-A")
	if baseline_damage <= 0:
		fail("missing baseline thunder damage against kashimo")
		return

	var resisted_content = _harness.build_loaded_content_index(sample_factory)
	resisted_content.register_resource(thunder_skill)
	resisted_content.units["sample_tidekit"].skill_ids[0] = thunder_skill.id
	var resisted_state = _support.build_battle_state(core, resisted_content, _support.build_kashimo_setup(sample_factory), 807)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(resisted_state, resisted_content, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-A", thunder_skill.id),
	])
	var resisted_damage: int = _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P2-A")
	var expected_resisted_damage: int = core.service("damage_service").apply_final_mod(baseline_damage, 0.5)
	if resisted_damage != expected_resisted_damage:
		fail("kashimo thunder resist mismatch: expected=%d actual=%d baseline=%d" % [expected_resisted_damage, resisted_damage, baseline_damage])
		return

func test_kashimo_water_leak_counter_contract() -> void:
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
	var water_skill = SkillDefinitionScript.new()
	water_skill.id = "test_kashimo_incoming_water"
	water_skill.display_name = "Incoming Water"
	water_skill.damage_kind = "special"
	water_skill.power = 40
	water_skill.accuracy = 100
	water_skill.mp_cost = 0
	water_skill.priority = 0
	water_skill.targeting = "enemy_active_slot"
	water_skill.combat_type_id = "water"
	content_index.register_resource(water_skill)
	content_index.units["sample_mossaur"].skill_ids[0] = water_skill.id
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, 808)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var attacker = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or attacker == null:
		fail("missing active units for water leak contract")
		return
	kashimo.current_hp = 1
	kashimo.current_mp = 20
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_skill_command(core, 1, "P2", "P2-C", water_skill.id),
	])
	if kashimo.current_hp != 0:
		fail("water leak contract should still allow lethal hit to KO kashimo")
		return
	if kashimo.current_mp != 5:
		fail("water leak should reduce kashimo mp by 15 even on lethal hit: expected=5 actual=%d" % kashimo.current_mp)
		return
	var expected_counter_damage: int = _support.calc_expected_fixed_effect_damage(core, content_index, "kashimo_water_leak_counter_listener", attacker)
	var actual_counter_damage: int = _find_counter_damage(core.service("battle_logger").event_log, attacker.unit_instance_id)
	if actual_counter_damage != expected_counter_damage:
		fail("water leak counter damage mismatch: expected=%d actual=%d" % [expected_counter_damage, actual_counter_damage])
		return

func test_kashimo_water_leak_ultimate_counter_contract() -> void:
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
	var water_ultimate = SkillDefinitionScript.new()
	water_ultimate.id = "test_kashimo_incoming_water_ultimate"
	water_ultimate.display_name = "Incoming Water Ultimate"
	water_ultimate.damage_kind = "special"
	water_ultimate.power = 40
	water_ultimate.accuracy = 100
	water_ultimate.mp_cost = 0
	water_ultimate.priority = 0
	water_ultimate.targeting = "enemy_active_slot"
	water_ultimate.combat_type_id = "water"
	content_index.register_resource(water_ultimate)
	content_index.units["sample_mossaur"].ultimate_skill_id = water_ultimate.id
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, 809)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var attacker = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or attacker == null:
		fail("missing active units for water leak ultimate contract")
		return
	kashimo.current_mp = 20
	attacker.current_mp = attacker.max_mp
	attacker.ultimate_points = attacker.ultimate_points_cap
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_ultimate_command(core, 1, "P2", "P2-C", water_ultimate.id),
	])
	if kashimo.current_mp != 5:
		fail("water leak should still reduce kashimo mp by 15 when hit by a water ultimate: expected=5 actual=%d" % kashimo.current_mp)
		return
	var expected_counter_damage: int = _support.calc_expected_fixed_effect_damage(core, content_index, "kashimo_water_leak_counter_listener", attacker)
	var actual_counter_damage: int = _find_counter_damage(core.service("battle_logger").event_log, attacker.unit_instance_id)
	if actual_counter_damage != expected_counter_damage:
		fail("water leak counter damage should also trigger on water ultimate hit: expected=%d actual=%d" % [expected_counter_damage, actual_counter_damage])
		return

