extends "res://tests/support/gdunit_suite_bridge.gd"

const EventTypesScript := preload("res://src/shared/event_types.gd")
const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()

@warning_ignore("shadowed_global_identifier")
func _build_gojo_vs_sample_state(harness, seed: int) -> Dictionary:
	return _support.build_gojo_vs_sample_state(harness, seed)

@warning_ignore("shadowed_global_identifier")
func _build_sample_vs_gojo_state(harness, seed: int, use_sukuna: bool) -> Dictionary:
	return _support.build_sample_vs_gojo_state(harness, seed, use_sukuna)

@warning_ignore("shadowed_global_identifier")
func _build_gojo_battle_state(harness, seed: int, use_sukuna: bool, gojo_on_p1: bool) -> Dictionary:
	return _support.build_gojo_battle_state(harness, seed, use_sukuna, gojo_on_p1)

func _build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _support.build_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func _build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _support.build_wait_command(core, turn_index, side_id, actor_public_id)

func _build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return _support.build_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func _build_resolved_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, actor_id: String, skill_id: String):
	return _support.build_resolved_skill_command(core, turn_index, side_id, actor_public_id, actor_id, skill_id)

func _build_accuracy_skill(skill_id: String, accuracy: int):
	return _support.build_accuracy_skill(skill_id, accuracy)

func _apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id: String, source_speed: int, source_owner_id: String = "") -> void:
	_support.apply_gojo_double_marks(core, content_index, battle_state, target_unit, source_instance_id, source_speed, source_owner_id)

func _set_field_state(battle_state, field_id: String, creator_id: String) -> void:
	_support.set_field_state(battle_state, field_id, creator_id)

func _find_unit_on_side(battle_state, side_id: String, definition_id: String):
	return _support.find_unit_on_side(battle_state, side_id, definition_id)

func _find_effect_instance(unit_state, effect_id: String):
	return _support.find_effect_instance(unit_state, effect_id)

func _count_effect_instances(unit_state, effect_id: String) -> int:
	return _support.count_effect_instances(unit_state, effect_id)

func _count_rule_mod_instances(unit_state, mod_kind: String) -> int:
	return _support.count_rule_mod_instances(unit_state, mod_kind)

func _count_target_damage_events(event_log: Array, target_unit_id: String) -> int:
	return _support.count_target_damage_events(event_log, EventTypesScript.EFFECT_DAMAGE, target_unit_id)

func _has_event(event_log: Array, predicate: Callable) -> bool:
	return _support.has_event(event_log, predicate)

func _find_burst_damage_event(event_log: Array, target_unit_id: String, target_public_id: String):
	for ev in event_log:
		if ev.event_type != EventTypesScript.EFFECT_DAMAGE or ev.target_instance_id != target_unit_id:
			continue
		var summary := str(ev.payload_summary)
		if summary.begins_with("%s damage " % target_public_id):
			return ev
	return null

func _first_value_change(log_event):
	if log_event == null:
		return null
	if log_event.value_changes == null or log_event.value_changes.is_empty():
		return null
	return log_event.value_changes[0]

func _calc_formula_damage(core, battle_state, power: int, damage_kind: String, actor, target, combat_type_id: String) -> int:
	var attack_base: int = actor.base_attack
	var defense_base: int = target.base_defense
	var attack_stage: int = int(actor.stat_stages.get("attack", 0))
	var defense_stage: int = int(target.stat_stages.get("defense", 0))
	if damage_kind == "special":
		attack_base = actor.base_sp_attack
		defense_base = target.base_sp_defense
		attack_stage = int(actor.stat_stages.get("sp_attack", 0))
		defense_stage = int(target.stat_stages.get("sp_defense", 0))
	var attack_value = core.service("stat_calculator").calc_effective_stat(attack_base, attack_stage)
	var defense_value = core.service("stat_calculator").calc_effective_stat(defense_base, defense_stage)
	var effectiveness = core.service("combat_type_service").calc_effectiveness(combat_type_id, target.combat_type_ids)
	var final_multiplier = core.service("rule_mod_service").get_final_multiplier(battle_state, actor.unit_instance_id)
	return core.service("damage_service").apply_final_mod(
		core.service("damage_service").calc_base_damage(
			battle_state.battle_level,
			max(1, power),
			attack_value,
			defense_value
		),
		final_multiplier * effectiveness
	)
