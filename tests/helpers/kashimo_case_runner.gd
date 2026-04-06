extends SceneTree

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")

var _harness := BattleCoreTestHarnessScript.new()
var _support := KashimoTestSupportScript.new()

func _init() -> void:
	var case_name := str(OS.get_environment("CASE")).strip_edges().to_lower()
	if case_name.is_empty():
		case_name = "all"
	_run_cases(case_name)
	_harness.dispose_core_pool()
	quit()

func _run_cases(case_name: String) -> void:
	var cases := [
		"charge_loop",
		"amber_switch_retention",
		"kyokyo_vs_domain",
	]
	for fixed_case in cases:
		if case_name != "all" and case_name != fixed_case:
			continue
		var result := _run_case(fixed_case)
		print("%s %s" % [fixed_case, JSON.stringify(result)])

func _run_case(case_name: String) -> Dictionary:
	match case_name:
		"charge_loop":
			return _run_charge_loop()
		"amber_switch_retention":
			return _run_amber_switch_retention()
		"kyokyo_vs_domain":
			return _run_kyokyo_vs_domain()
		_:
			return {"error": "unknown case: %s" % case_name}

func _run_charge_loop() -> Dictionary:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		return core_payload
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_setup = _support.build_kashimo_setup(sample_factory)
	battle_setup.sides[1].starting_index = 2
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, 6101)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if kashimo == null or target == null:
		return {"error": "missing active units for charge loop case"}

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "kashimo_raiken"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-C"),
	])
	var turn_one_negative_stacks := _support.count_effect_instances(target, "kashimo_negative_charge_mark")

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 2, "P1", "P1-A", "kashimo_charge"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-C"),
	])
	var turn_two_positive_stacks := _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark")

	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 3, "P1", "P1-A", "kashimo_feedback_strike"),
		_support.build_manual_wait_command(core, 3, "P2", "P2-C"),
	])
	return {
		"target_public_id": String(target.public_id),
		"turn1_negative_stacks": turn_one_negative_stacks,
		"turn2_positive_stacks": turn_two_positive_stacks,
		"turn3_damage": _harness.extract_damage_from_log(core.service("battle_logger").event_log, "P1-A"),
		"turn3_target_negative_stacks": _support.count_effect_instances(target, "kashimo_negative_charge_mark"),
		"turn3_self_positive_stacks": _support.count_effect_instances(kashimo, "kashimo_positive_charge_mark"),
		"turn3_target_hp": int(target.current_hp),
		"log_size": core.service("battle_logger").event_log.size(),
	}

func _run_amber_switch_retention() -> Dictionary:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		return core_payload
	var core = core_payload["core"]
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_kashimo_setup(sample_factory), 6102)
	var kashimo = battle_state.get_side("P1").get_active_unit()
	if kashimo == null:
		return {"error": "missing kashimo active unit for amber case"}
	kashimo.current_mp = kashimo.max_mp
	kashimo.ultimate_points = kashimo.ultimate_points_cap

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "kashimo_phantom_beast_amber"),
		_support.build_manual_wait_command(core, 1, "P2", _active_public_id(battle_state, "P2")),
	])
	var hp_after_cast := int(kashimo.current_hp)

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 2, "P1", "P1-A", "P1-B"),
		_support.build_manual_wait_command(core, 2, "P2", _active_public_id(battle_state, "P2")),
	])
	var hp_after_switch_out := int(kashimo.current_hp)

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_switch_command(core, 3, "P1", "P1-B", "P1-A"),
		_support.build_manual_wait_command(core, 3, "P2", _active_public_id(battle_state, "P2")),
	])
	var hp_after_reenter_same_turn := int(kashimo.current_hp)

	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 4, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 4, "P2", _active_public_id(battle_state, "P2")),
	])
	return {
		"hp_after_cast": hp_after_cast,
		"hp_after_switch_out": hp_after_switch_out,
		"hp_after_reenter_same_turn": hp_after_reenter_same_turn,
		"hp_after_resume_turn": int(kashimo.current_hp),
		"persistent_attack_stage": int(kashimo.persistent_stat_stages.get("attack", 0)),
		"persistent_sp_attack_stage": int(kashimo.persistent_stat_stages.get("sp_attack", 0)),
		"persistent_speed_stage": int(kashimo.persistent_stat_stages.get("speed", 0)),
		"bleed_present": _has_effect_instance(kashimo, "kashimo_amber_bleed"),
		"ultimate_lock_present": _support.has_rule_mod(kashimo, "action_legality", "ultimate"),
	}

func _run_kyokyo_vs_domain() -> Dictionary:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}
	var seed_result = _support.find_gojo_domain_accuracy_probe_seed(_harness, sample_factory, 6103)
	if not bool(seed_result.get("ok", false)):
		return {"error": str(seed_result.get("error", "failed to find gojo domain accuracy probe seed"))}
	var probe_seed := int(seed_result.get("seed", 0))
	var baseline_payload = _support.run_gojo_domain_accuracy_case(_harness, sample_factory, false, probe_seed)
	if not bool(baseline_payload.get("ok", false)):
		return baseline_payload
	var protected_payload = _support.run_gojo_domain_accuracy_case(_harness, sample_factory, true, probe_seed)
	if not bool(protected_payload.get("ok", false)):
		return protected_payload
	return {
		"field_id": protected_payload.get("field_id", null),
		"baseline_damage": int(baseline_payload.get("damage", 0)),
		"protected_damage": int(protected_payload.get("damage", 0)),
		"nullify_rule_mod_present": bool(protected_payload.get("nullify_active", false)),
		"log_size": int(protected_payload.get("log_size", 0)),
	}

func _has_effect_instance(unit_state, effect_id: String) -> bool:
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == effect_id:
			return true
	return false

func _active_public_id(battle_state, side_id: String) -> String:
	var side = battle_state.get_side(side_id)
	if side == null:
		return ""
	var active = side.get_active_unit()
	if active == null:
		return ""
	return String(active.public_id)
