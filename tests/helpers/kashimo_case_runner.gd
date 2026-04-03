extends SceneTree

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")
const KashimoTestSupportScript := preload("res://tests/support/kashimo_test_support.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const FieldStateScript := preload("res://src/battle_core/runtime/field_state.gd")

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
		"ultimate_lock_present": _has_rule_mod(kashimo, "action_legality", "ultimate"),
	}

func _run_kyokyo_vs_domain() -> Dictionary:
	var sample_factory = _harness.build_sample_factory()
	if sample_factory == null:
		return {"error": "SampleBattleFactory init failed"}

	var baseline_payload = _build_domain_case_state(sample_factory, 6103)
	if baseline_payload.has("error"):
		return baseline_payload
	var baseline_core = baseline_payload["core"]
	var baseline_content = baseline_payload["content_index"]
	var baseline_state = baseline_payload["battle_state"]
	var baseline_target = baseline_state.get_side("P1").get_active_unit()
	var baseline_actor = baseline_state.get_side("P2").get_active_unit()
	if baseline_target == null or baseline_actor == null:
		return {"error": "missing active units for kyokyo baseline case"}
	baseline_state.field_state = _build_override_field_state("gojo_unlimited_void_field", baseline_actor.unit_instance_id)
	baseline_core.service("battle_logger").reset()
	baseline_core.service("turn_loop_controller").run_turn(baseline_state, baseline_content, [
		_support.build_manual_wait_command(baseline_core, 1, "P1", "P1-A"),
		_support.build_manual_skill_command(baseline_core, 1, "P2", "P2-A", "test_kashimo_zero_accuracy_domain_hit"),
	])
	var baseline_damage := _harness.extract_damage_from_log(baseline_core.service("battle_logger").event_log, "P2-A")

	var kyokyo_loadout := {0: PackedStringArray(["kashimo_raiken", "kashimo_charge", "kashimo_kyokyo_katsura"])}
	var protected_payload = _build_domain_case_state(sample_factory, 6104, kyokyo_loadout)
	if protected_payload.has("error"):
		return protected_payload
	var protected_core = protected_payload["core"]
	var protected_content = protected_payload["content_index"]
	var protected_state = protected_payload["battle_state"]
	var protected_target = protected_state.get_side("P1").get_active_unit()
	var protected_actor = protected_state.get_side("P2").get_active_unit()
	if protected_target == null or protected_actor == null:
		return {"error": "missing active units for kyokyo protected case"}
	protected_state.field_state = _build_override_field_state("gojo_unlimited_void_field", protected_actor.unit_instance_id)
	protected_core.service("battle_logger").reset()
	protected_core.service("turn_loop_controller").run_turn(protected_state, protected_content, [
		_support.build_manual_skill_command(protected_core, 1, "P1", "P1-A", "kashimo_kyokyo_katsura"),
		_support.build_manual_skill_command(protected_core, 1, "P2", "P2-A", "test_kashimo_zero_accuracy_domain_hit"),
	])
	return {
		"field_id": String(protected_state.field_state.field_def_id) if protected_state.field_state != null else null,
		"baseline_damage": baseline_damage,
		"protected_damage": _harness.extract_damage_from_log(protected_core.service("battle_logger").event_log, "P2-A"),
		"nullify_rule_mod_present": _has_rule_mod(protected_target, "nullify_field_accuracy"),
		"log_size": protected_core.service("battle_logger").event_log.size(),
	}

func _build_domain_case_state(sample_factory, seed: int, p1_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	var core_payload = _harness.build_core()
	if core_payload.has("error"):
		return core_payload
	var core = core_payload["core"]
	var content_index = _harness.build_loaded_content_index(sample_factory)
	var zero_skill = SkillDefinitionScript.new()
	zero_skill.id = "test_kashimo_zero_accuracy_domain_hit"
	zero_skill.display_name = "Kashimo Zero Accuracy Domain Hit"
	zero_skill.damage_kind = "special"
	zero_skill.power = 40
	zero_skill.accuracy = 0
	zero_skill.mp_cost = 0
	zero_skill.priority = 0
	zero_skill.targeting = "enemy_active_slot"
	zero_skill.combat_type_id = "fire"
	content_index.register_resource(zero_skill)
	content_index.units["sample_tidekit"].skill_ids[0] = zero_skill.id
	return {
		"core": core,
		"content_index": content_index,
		"battle_state": _support.build_battle_state(
			core,
			content_index,
			_support.build_kashimo_setup(sample_factory, p1_regular_skill_overrides),
			seed
		),
	}

func _build_override_field_state(field_def_id: String, creator_id: String):
	var field_state = FieldStateScript.new()
	field_state.field_def_id = field_def_id
	field_state.instance_id = "test_kashimo_field_override"
	field_state.creator = creator_id
	field_state.remaining_turns = 3
	return field_state

func _has_effect_instance(unit_state, effect_id: String) -> bool:
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == effect_id:
			return true
	return false

func _has_rule_mod(unit_state, mod_kind: String, value: Variant = null) -> bool:
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) != mod_kind:
			continue
		if value != null and String(rule_mod_instance.value) != String(value):
			continue
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
