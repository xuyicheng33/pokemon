extends RefCounted
class_name SandboxViewFormatHelper

const StatusFormatterScript := preload("res://src/adapters/sandbox_view_status_formatter.gd")
const SideFormatterScript := preload("res://src/adapters/sandbox_view_side_formatter.gd")

var _status_formatter = StatusFormatterScript.new()
var _side_formatter = SideFormatterScript.new()

func format_status_text(state: SandboxSessionState, current_view_model: Dictionary) -> String:
	return _status_formatter.format_status_text(state, current_view_model)

func format_config_status_text(state: SandboxSessionState) -> String:
	return _status_formatter.format_config_status_text(state)

func format_battle_summary_text(battle_summary: Dictionary) -> String:
	return _status_formatter.format_battle_summary_text(battle_summary)

func format_side_text(current_view_model: Dictionary, side_id: String, side_control_modes: Dictionary) -> String:
	return _side_formatter.format_side_text(current_view_model, side_id, side_control_modes)

func format_unit_block(label: String, unit_model: Dictionary) -> String:
	return _side_formatter.format_unit_block(label, unit_model)

func format_unit_list(label: String, units: Array) -> String:
	return _side_formatter.format_unit_list(label, units)

func format_effects(effects: Array) -> String:
	return _side_formatter.format_effects(effects)

func format_pending_text(current_view_model: Dictionary, battle_summary: Dictionary) -> String:
	return _status_formatter.format_pending_text(current_view_model, battle_summary)

func format_action_header(state: SandboxSessionState, current_view_model: Dictionary) -> String:
	return _status_formatter.format_action_header(state, current_view_model)

func format_policy_status(side_control_modes: Dictionary, current_side: String, battle_finished: bool) -> String:
	return _status_formatter.format_policy_status(side_control_modes, current_side, battle_finished)

func find_side_model(side_models: Array, side_id: String) -> Dictionary:
	return _side_formatter.find_side_model(side_models, side_id)

func control_mode_for_side(side_control_modes: Dictionary, side_id: String) -> String:
	return _status_formatter.control_mode_for_side(side_control_modes, side_id)

func is_policy_side(side_control_modes: Dictionary, side_id: String) -> bool:
	return _status_formatter.is_policy_side(side_control_modes, side_id)

func has_battle_result(public_snapshot: Dictionary) -> bool:
	return _status_formatter.has_battle_result(public_snapshot)

func value_or_dash(value: String) -> String:
	return _status_formatter.value_or_dash(value)

func format_event_header_text(state: SandboxSessionState, current_view_model: Dictionary) -> String:
	return _status_formatter.format_event_header_text(state, current_view_model)

func format_replay_turn_label(current_view_model: Dictionary) -> String:
	return _status_formatter.format_replay_turn_label(current_view_model)
