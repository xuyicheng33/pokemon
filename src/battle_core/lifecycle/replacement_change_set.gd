extends RefCounted
class_name ReplacementChangeSet

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var bench_order: PackedStringArray = PackedStringArray()
var active_slots: Dictionary = {}
var target_effect_instances: Array = []
var target_rule_mod_instances: Array = []
var target_stat_stages: Dictionary = {}
var target_persistent_stat_stages: Dictionary = {}
var target_has_acted: bool = false
var target_action_window_passed: bool = false
var target_leave_reason: Variant = null
var target_leave_state: String = LeaveStatesScript.ACTIVE
var target_current_hp: int = 0
var target_reentered_turn_index: int = -1
var selected_has_acted: bool = false
var selected_action_window_passed: bool = false
var selected_leave_reason: Variant = null
var selected_leave_state: String = LeaveStatesScript.ACTIVE
var selected_reentered_turn_index: int = -1
var field_state: Variant = null
var field_rule_mod_instances: Array = []
var battle_log_size: int = 0

static func collect_changes(battle_state: BattleState, side_state, target_unit, selected_unit, battle_logger: BattleLogger) -> ReplacementChangeSet:
	var change_set := ReplacementChangeSet.new()
	change_set.bench_order = side_state.bench_order.duplicate()
	change_set.active_slots = side_state.active_slots.duplicate(true)
	change_set.target_effect_instances = target_unit.effect_instances.duplicate()
	change_set.target_rule_mod_instances = target_unit.rule_mod_instances.duplicate()
	change_set.target_stat_stages = target_unit.stat_stages.duplicate(true)
	change_set.target_persistent_stat_stages = target_unit.persistent_stat_stages.duplicate(true)
	change_set.target_has_acted = bool(target_unit.has_acted)
	change_set.target_action_window_passed = bool(target_unit.action_window_passed)
	change_set.target_leave_reason = target_unit.leave_reason
	change_set.target_leave_state = String(target_unit.leave_state)
	change_set.target_current_hp = int(target_unit.current_hp)
	change_set.target_reentered_turn_index = int(target_unit.reentered_turn_index)
	change_set.selected_has_acted = bool(selected_unit.has_acted)
	change_set.selected_action_window_passed = bool(selected_unit.action_window_passed)
	change_set.selected_leave_reason = selected_unit.leave_reason
	change_set.selected_leave_state = String(selected_unit.leave_state)
	change_set.selected_reentered_turn_index = int(selected_unit.reentered_turn_index)
	change_set.field_state = battle_state.field_state
	change_set.field_rule_mod_instances = battle_state.field_rule_mod_instances.duplicate()
	change_set.battle_log_size = battle_logger.event_log.size() if battle_logger != null else 0
	return change_set

func apply_change_set(battle_state: BattleState, side_state, target_unit, selected_unit, battle_logger: BattleLogger) -> void:
	side_state.bench_order = PackedStringArray(bench_order)
	side_state.active_slots = active_slots.duplicate(true)
	target_unit.effect_instances = target_effect_instances.duplicate()
	target_unit.rule_mod_instances = target_rule_mod_instances.duplicate()
	target_unit.stat_stages = target_stat_stages.duplicate(true)
	target_unit.persistent_stat_stages = target_persistent_stat_stages.duplicate(true)
	target_unit.has_acted = target_has_acted
	target_unit.action_window_passed = target_action_window_passed
	target_unit.leave_reason = target_leave_reason
	target_unit.leave_state = target_leave_state
	target_unit.current_hp = target_current_hp
	target_unit.reentered_turn_index = target_reentered_turn_index
	selected_unit.has_acted = selected_has_acted
	selected_unit.action_window_passed = selected_action_window_passed
	selected_unit.leave_reason = selected_leave_reason
	selected_unit.leave_state = selected_leave_state
	selected_unit.reentered_turn_index = selected_reentered_turn_index
	battle_state.field_state = field_state
	battle_state.field_rule_mod_instances = field_rule_mod_instances.duplicate()
	if battle_logger != null:
		battle_logger.event_log.resize(battle_log_size)
