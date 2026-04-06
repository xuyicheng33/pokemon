extends RefCounted
class_name FormalCharacterTestSupport

const DomainRoleTestSupportScript := preload("res://tests/support/domain_role_test_support.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var _domain_support = DomainRoleTestSupportScript.new()

func build_matchup_setup(sample_factory, matchup_id: String, side_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_matchup_setup_result(sample_factory, matchup_id, side_regular_skill_overrides))

func build_matchup_setup_result(sample_factory, matchup_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return sample_factory.build_setup_by_matchup_id_result(matchup_id, side_regular_skill_overrides)

func build_formal_character_setup(sample_factory, character_id: String, side_regular_skill_overrides: Dictionary = {}):
	return _unwrap_setup_result(build_formal_character_setup_result(sample_factory, character_id, side_regular_skill_overrides))

func build_formal_character_setup_result(sample_factory, character_id: String, side_regular_skill_overrides: Dictionary = {}) -> Dictionary:
	return sample_factory.build_formal_character_setup_result(character_id, side_regular_skill_overrides)

func build_setup(
	sample_factory,
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
):
	return _unwrap_setup_result(build_setup_result(
		sample_factory,
		p1_unit_definition_ids,
		p2_unit_definition_ids,
		side_regular_skill_overrides,
		p1_starting_index,
		p2_starting_index
	))

func build_setup_result(
	sample_factory,
	p1_unit_definition_ids: PackedStringArray,
	p2_unit_definition_ids: PackedStringArray,
	side_regular_skill_overrides: Dictionary = {},
	p1_starting_index: int = 0,
	p2_starting_index: int = 0
) -> Dictionary:
	return sample_factory.build_setup_from_side_specs_result(
		sample_factory.build_side_spec(
			p1_unit_definition_ids,
			p1_starting_index,
			side_regular_skill_overrides.get("P1", {})
		),
		sample_factory.build_side_spec(
			p2_unit_definition_ids,
			p2_starting_index,
			side_regular_skill_overrides.get("P2", {})
		)
	)

func build_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func build_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func build_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return build_manual_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func _unwrap_setup_result(result: Dictionary):
	assert(result != null, "FormalCharacterTestSupport requires non-null setup result")
	assert(bool(result.get("ok", false)), "FormalCharacterTestSupport build failed: %s (%s)" % [
		str(result.get("error_message", "unknown error")),
		str(result.get("error_code", "unknown_error_code")),
	])
	return result.get("data", null)

func build_battle_state(core, content_index, battle_setup, seed: int):
	return _domain_support.build_battle_state(core, content_index, battle_setup, seed)

func build_manual_skill_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _domain_support.build_manual_skill_command(core, turn_index, side_id, actor_public_id, skill_id)

func build_manual_wait_command(core, turn_index: int, side_id: String, actor_public_id: String):
	return _domain_support.build_manual_wait_command(core, turn_index, side_id, actor_public_id)

func build_manual_switch_command(core, turn_index: int, side_id: String, actor_public_id: String, target_public_id: String):
	return _domain_support.build_manual_switch_command(core, turn_index, side_id, actor_public_id, target_public_id)

func build_manual_ultimate_command(core, turn_index: int, side_id: String, actor_public_id: String, skill_id: String):
	return _domain_support.build_manual_ultimate_command(core, turn_index, side_id, actor_public_id, skill_id)

func sum_unit_bst(unit_state) -> int:
	return _domain_support.sum_unit_bst(unit_state)

func resolve_matchup_gap_value(owner_total: int, opponent_total: int, thresholds: PackedInt32Array, outputs: PackedInt32Array, default_value: int) -> int:
	return _domain_support.resolve_matchup_gap_value(owner_total, opponent_total, thresholds, outputs, default_value)

func find_unit_on_side(battle_state, side_id: String, definition_id: String):
	var side_state = battle_state.get_side(side_id)
	if side_state == null:
		return null
	for unit_state in side_state.team_units:
		if String(unit_state.definition_id) == definition_id:
			return unit_state
	return null

func find_effect_instance(unit_state, effect_id: String):
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == effect_id:
			return effect_instance
	return null

func find_rule_mod_instance(unit_state, mod_kind: String):
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == mod_kind:
			return rule_mod_instance
	return null

func count_effect_instances(unit_state, effect_id: String) -> int:
	var count := 0
	for effect_instance in unit_state.effect_instances:
		if String(effect_instance.def_id) == effect_id:
			count += 1
	return count

func count_rule_mod_instances(unit_state, mod_kind: String) -> int:
	var count := 0
	for rule_mod_instance in unit_state.rule_mod_instances:
		if String(rule_mod_instance.mod_kind) == mod_kind:
			count += 1
	return count

func count_target_damage_events(event_log: Array, event_type: String, target_unit_id: String) -> int:
	var count := 0
	for event in event_log:
		if String(event.event_type) != event_type:
			continue
		if String(event.target_instance_id) != target_unit_id:
			continue
		count += 1
	return count

func collect_actor_damage_events(event_log: Array, actor_public_id: String) -> Array:
	var matched: Array = []
	for event in event_log:
		if String(event.event_type) != EventTypesScript.EFFECT_DAMAGE:
			continue
		if String(event.payload_summary).begins_with("%s dealt " % actor_public_id):
			matched.append(event)
	return matched

func collect_target_heal_events(event_log: Array, target_unit_id: String) -> Array:
	var matched: Array = []
	for event in event_log:
		if String(event.event_type) != EventTypesScript.EFFECT_HEAL:
			continue
		if String(event.target_instance_id) == target_unit_id:
			matched.append(event)
	return matched

func has_event(event_log: Array, predicate: Callable) -> bool:
	for event in event_log:
		if bool(predicate.call(event)):
			return true
	return false
