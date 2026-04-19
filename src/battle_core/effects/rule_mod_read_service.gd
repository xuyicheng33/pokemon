extends RefCounted
class_name RuleModReadService

const RuleModActiveInstanceCollectorScript := preload("res://src/battle_core/effects/rule_mod_active_instance_collector.gd")
const RuleModLegalityQueryScript := preload("res://src/battle_core/effects/rule_mod_legality_query.gd")
const RuleModNumericQueryScript := preload("res://src/battle_core/effects/rule_mod_numeric_query.gd")
const ErrorStateHelperScript := preload("res://src/shared/error_state_helper.gd")

var last_error_code: Variant = null
var last_error_message: String = ""

var _collector = RuleModActiveInstanceCollectorScript.new()
var _legality_query = RuleModLegalityQueryScript.new()
var _numeric_query = RuleModNumericQueryScript.new()

func error_state() -> Dictionary:
	return ErrorStateHelperScript.error_state(self)

func get_final_multiplier(battle_state: BattleState, owner_id: String) -> float:
	_reset_error_state()
	if battle_state.get_unit(owner_id) == null:
		return 1.0
	return _numeric_query.resolve_final_multiplier(_ordered_instances_for_read(battle_state, owner_id))

func resolve_mp_regen_value(battle_state: BattleState, owner_id: String, base_regen: int) -> int:
	_reset_error_state()
	if battle_state.get_unit(owner_id) == null:
		return max(0, base_regen)
	return _numeric_query.resolve_mp_regen_value(_ordered_instances_for_read(battle_state, owner_id), base_regen)

func is_action_allowed(battle_state: BattleState, owner_id: String, action_type: String, skill_id: String = "") -> bool:
	_reset_error_state()
	if battle_state.get_unit(owner_id) == null:
		return false
	var result: Dictionary = _legality_query.is_action_allowed(
		_ordered_instances_for_read(battle_state, owner_id),
		action_type,
		skill_id
	)
	_apply_query_error(result)
	return bool(result.get("allowed", false))

func resolve_incoming_accuracy(battle_state: BattleState, owner_id: String, base_accuracy: int) -> int:
	_reset_error_state()
	if battle_state.get_unit(owner_id) == null:
		return clamp(base_accuracy, 0, 99)
	return _numeric_query.resolve_incoming_accuracy(_ordered_instances_for_read(battle_state, owner_id), base_accuracy)

func has_nullify_field_accuracy(battle_state: BattleState, owner_id: String) -> bool:
	_reset_error_state()
	if battle_state.get_unit(owner_id) == null:
		return false
	return _numeric_query.has_nullify_field_accuracy(_ordered_instances_for_read(battle_state, owner_id))

func resolve_incoming_heal_final_multiplier(battle_state: BattleState, owner_id: String) -> float:
	_reset_error_state()
	if battle_state.get_unit(owner_id) == null:
		return 1.0
	return _numeric_query.resolve_incoming_heal_final_multiplier(_ordered_instances_for_read(battle_state, owner_id))

func resolve_incoming_action_final_multiplier(battle_state: BattleState, owner_id: String, command_type: String, combat_type_id: String) -> float:
	_reset_error_state()
	if battle_state.get_unit(owner_id) == null:
		return 1.0
	return _numeric_query.resolve_incoming_action_final_multiplier(
		_ordered_instances_for_read(battle_state, owner_id),
		command_type,
		combat_type_id
	)

func _ordered_instances_for_read(battle_state: BattleState, owner_id: String) -> Array:
	return _collector.sorted_active_instances_for_read(battle_state, owner_id)

func _apply_query_error(result: Dictionary) -> void:
	ErrorStateHelperScript.capture_envelope(self, result)

func _reset_error_state() -> void:
	ErrorStateHelperScript.clear(self)
