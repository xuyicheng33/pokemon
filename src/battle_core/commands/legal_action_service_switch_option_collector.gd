extends RefCounted
class_name LegalActionServiceSwitchOptionCollector

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var rule_gate

func collect_switch_action_flags_result(battle_state: BattleState, side_state, actor, legal_action_set) -> Dictionary:
	var switch_allowed_by_rule_mod_result: Dictionary = rule_gate.action_allowed_result(
		battle_state,
		actor.unit_instance_id,
		CommandTypesScript.SWITCH
	)
	if not bool(switch_allowed_by_rule_mod_result.get("ok", false)):
		return switch_allowed_by_rule_mod_result
	var switch_allowed_by_rule_mod: bool = bool(switch_allowed_by_rule_mod_result.get("data", false))
	for bench_unit_id in side_state.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null and bench_unit.current_hp > 0 and switch_allowed_by_rule_mod:
			legal_action_set.legal_switch_target_public_ids.append(bench_unit.public_id)
	return ResultEnvelopeHelperScript.ok({
		"has_legal_switch": not legal_action_set.legal_switch_target_public_ids.is_empty(),
		"has_non_mp_blocked_option": not switch_allowed_by_rule_mod and _has_alive_bench_unit(battle_state, side_state),
	})

func _has_alive_bench_unit(battle_state: BattleState, side_state) -> bool:
	for bench_unit_id in side_state.bench_order:
		var bench_unit = battle_state.get_unit(bench_unit_id)
		if bench_unit != null and bench_unit.current_hp > 0:
			return true
	return false

