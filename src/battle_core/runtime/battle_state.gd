extends RefCounted
class_name BattleState

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var battle_id: String = ""
@warning_ignore("shadowed_global_identifier")
var seed: int = 0
var rng_profile: String = ""
var format_id: String = ""
var visibility_mode: String = ""
var max_turn: int = 0
var max_chain_depth: int = 32
var battle_level: int = 0
var selection_deadline_ms: int = 30000
var default_recoil_ratio: float = 0.25
var domain_clash_tie_threshold: float = 0.5
var turn_index: int = 0
var phase: String = BattlePhasesScript.BATTLE_INIT
var sides: Array = []
var field_state: FieldState = null
var pending_effect_queue: Array = []
var battle_result: BattleResult = null
var rng_stream_index: int = 0
var fatal_damage_records_by_target: Dictionary = {}
var field_rule_mod_instances: Array = []
var last_matchup_signature: String = ""
var pre_applied_turn_start_regen_turn_index: int = 0

# Phase-scope chain context stack. Direct field access is forbidden; use the
# push / pop / replace_phase / current API below. Any new ChainContext entered
# during a phase is replaced via `set_phase_chain_context`; nested scopes
# (effect chains triggering effect chains) must be wrapped in
# push_chain_context / pop_chain_context pairs and may not leak across phases.
var _chain_context_stack: Array = []

# runtime_fault_code / runtime_fault_message are written through one
# canonical method, `BattleState.record_runtime_fault`. The underscore prefix
# on the storage fields is a grep gate: direct assignment from outside this
# script is forbidden. Callers route through the public method
# (`BattleResultService` for coordinated terminate flow, `LogEventBuilder`
# and `TurnSelectionResolver` from their fail paths).
var _runtime_fault_code: String = ""
var _runtime_fault_message: String = ""

func get_side(side_id: String) -> Variant:
	return _find_side_by_id(side_id)

func get_opponent_side(side_id: String) -> Variant:
	for side_state in sides:
		if side_state.side_id != side_id:
			return side_state
	return null

func get_side_for_unit(unit_instance_id: String) -> Variant:
	for side_state in sides:
		if side_state.find_unit(unit_instance_id) != null:
			return side_state
	return null

func get_unit(unit_instance_id: String) -> Variant:
	return _find_unit_by_id(unit_instance_id)

func get_unit_by_public_id(public_id: String) -> Variant:
	return _find_unit_by_public_id(public_id)

func append_side(side_state) -> void:
	sides.append(side_state)

func get_active_unit(side_id: String, slot_id: String = ContentSchemaScript.ACTIVE_SLOT_PRIMARY) -> Variant:
	var side_state = get_side(side_id)
	if side_state == null:
		return null
	return side_state.get_active_unit(slot_id)

# Chain context phase-scope stack API. ----------------------------------------
# `current_chain_context()` peeks the active chain (read).
# `set_phase_chain_context(ctx)` is the canonical writer for turn / battle
#   phase boundaries. It tolerates an empty stack (push) or a depth-1 stack
#   (replace bottom) but fail-fasts when nested scopes from a previous phase
#   leaked. Pass `null` only for fail-fast hard-terminate paths via
#   `clear_chain_context_stack()`.
# `push_chain_context(ctx)` enters a nested chain scope (e.g. effect chain
#   triggering another effect chain). Must be paired with pop_chain_context().
# `pop_chain_context()` exits a nested scope and returns the popped chain.
# `clear_chain_context_stack()` resets the stack — used only by hard-terminate
#   paths after the runtime is already considered invalid.

func current_chain_context() -> Variant:
	if _chain_context_stack.is_empty():
		return null
	return _chain_context_stack[_chain_context_stack.size() - 1]

func chain_context_stack_depth() -> int:
	return _chain_context_stack.size()

func set_phase_chain_context(chain_context) -> void:
	# Phase services replace the active phase chain. If a previous phase left
	# nested scopes on the stack we fail-fast: that means a push_chain_context
	# was never paired with pop_chain_context.
	if _chain_context_stack.size() > 1:
		var leak_message := "BattleState.set_phase_chain_context detected leaked nested chain scopes (depth=%d)" % _chain_context_stack.size()
		push_error(leak_message)
		assert(false, leak_message)
		_chain_context_stack.clear()
	if _chain_context_stack.is_empty():
		_chain_context_stack.append(chain_context)
	else:
		_chain_context_stack[0] = chain_context

func push_chain_context(chain_context) -> void:
	_chain_context_stack.append(chain_context)

func pop_chain_context() -> Variant:
	if _chain_context_stack.is_empty():
		var underflow_message := "BattleState.pop_chain_context called with empty stack"
		push_error(underflow_message)
		assert(false, underflow_message)
		return null
	return _chain_context_stack.pop_back()

func clear_chain_context_stack() -> void:
	_chain_context_stack.clear()

# runtime_fault recorder. -----------------------------------------------------
# Canonical single writer for `_runtime_fault_*`. Readers call
# `runtime_fault_code()` / `runtime_fault_message()`. All writers (the
# coordinated terminate flow in BattleResultService, LogEventBuilder._fail,
# TurnSelectionResolver._fail_invalid_result) route through this method;
# direct field assignment from outside this script is forbidden.
func record_runtime_fault(code: String, message: String) -> void:
	_runtime_fault_code = code
	_runtime_fault_message = message

func runtime_fault_code() -> String:
	return _runtime_fault_code

func runtime_fault_message() -> String:
	return _runtime_fault_message

# Omitted from stable dict (transient per-turn state, reset between turns):
#   pending_effect_queue, _chain_context_stack, fatal_damage_records_by_target.
# Included as `runtime_fault_code` / `runtime_fault_message` keys (sourced from
# the private `_runtime_fault_code` / `_runtime_fault_message` fields via the
# `record_runtime_fault` single-writer): once a runtime fault is recorded the
# battle is considered terminated, so the fields participate in the stable hash.
func to_stable_dict() -> Dictionary:
	var side_dicts: Array = []
	var sorted_sides = sides.duplicate()
	sorted_sides.sort_custom(func(a, b): return a.side_id < b.side_id)
	for side_state in sorted_sides:
		side_dicts.append(side_state.to_stable_dict())
	var field_rule_mod_dicts: Array = []
	var sorted_field_rule_mods = field_rule_mod_instances.duplicate()
	sorted_field_rule_mods.sort_custom(func(a, b): return a.instance_id < b.instance_id)
	for rule_mod_instance in sorted_field_rule_mods:
		field_rule_mod_dicts.append(rule_mod_instance.to_stable_dict())
	var field_state_dict: Variant = null
	if field_state != null:
		field_state_dict = field_state.to_stable_dict()
	var battle_result_dict: Variant = null
	if battle_result != null:
		battle_result_dict = battle_result.to_stable_dict()
	return {
		"battle_id": battle_id,
		"seed": seed,
		"rng_profile": rng_profile,
		"format_id": format_id,
		"visibility_mode": visibility_mode,
		"max_turn": max_turn,
		"max_chain_depth": max_chain_depth,
		"battle_level": battle_level,
		"selection_deadline_ms": selection_deadline_ms,
		"default_recoil_ratio": default_recoil_ratio,
		"domain_clash_tie_threshold": domain_clash_tie_threshold,
		"turn_index": turn_index,
		"phase": phase,
		"sides": side_dicts,
		"field_state": field_state_dict,
		"field_rule_mod_instances": field_rule_mod_dicts,
		"last_matchup_signature": last_matchup_signature,
		"pre_applied_turn_start_regen_turn_index": pre_applied_turn_start_regen_turn_index,
		"runtime_fault_code": _runtime_fault_code,
		"runtime_fault_message": _runtime_fault_message,
		"battle_result": battle_result_dict,
		"rng_stream_index": rng_stream_index,
	}

func _find_side_by_id(side_id: String) -> Variant:
	for side_state in sides:
		if side_state.side_id == side_id:
			return side_state
	return null

func _find_unit_by_id(unit_instance_id: String) -> Variant:
	for side_state in sides:
		for unit_state in side_state.team_units:
			if unit_state.unit_instance_id == unit_instance_id:
				return unit_state
	return null

func _find_unit_by_public_id(public_id: String) -> Variant:
	for side_state in sides:
		for unit_state in side_state.team_units:
			if unit_state.public_id == public_id:
				return unit_state
	return null
