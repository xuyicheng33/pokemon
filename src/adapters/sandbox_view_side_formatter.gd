extends RefCounted
class_name SandboxViewSideFormatter

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")

func format_side_text(current_view_model: Dictionary, side_id: String, side_control_modes: Dictionary) -> String:
	var side_model = find_side_model(current_view_model.get("sides", []), side_id)
	if side_model.is_empty():
		return "%s\nmissing side snapshot" % side_id
	var lines = [
		"%s (%s)" % [side_id, control_mode_for_side(side_control_modes, side_id)],
		format_unit_block("Active", side_model.get("active", {})),
		format_unit_list("Bench", side_model.get("bench", [])),
		format_unit_list("Team", side_model.get("team_units", [])),
	]
	return "\n".join(lines)

func format_unit_block(label: String, unit_model: Dictionary) -> String:
	if unit_model.is_empty():
		return "%s: -" % label
	var effect_text = format_effects(unit_model.get("effects", []))
	return "%s: %s [%s]\nHP %d/%d | MP %d/%d | UP %d/%d req=%d\nType %s | Leave %s/%s\nEffects %s" % [
		label,
		str(unit_model.get("display_name", "")),
		str(unit_model.get("public_id", "")),
		int(unit_model.get("current_hp", 0)),
		int(unit_model.get("max_hp", 0)),
		int(unit_model.get("current_mp", 0)),
		int(unit_model.get("max_mp", 0)),
		int(unit_model.get("ultimate_points", 0)),
		int(unit_model.get("ultimate_points_cap", 0)),
		int(unit_model.get("ultimate_points_required", 0)),
		",".join(unit_model.get("combat_type_ids", [])),
		str(unit_model.get("leave_state", "-")),
		str(unit_model.get("leave_reason", "-")),
		effect_text,
	]

func format_unit_list(label: String, units: Array) -> String:
	if units.is_empty():
		return "%s: -" % label
	var lines: Array = ["%s:" % label]
	for unit_model in units:
		if not (unit_model is Dictionary):
			continue
		lines.append("- %s [%s] HP %d/%d MP %d/%d UP %d/%d" % [
			str(unit_model.get("display_name", "")),
			str(unit_model.get("public_id", "")),
			int(unit_model.get("current_hp", 0)),
			int(unit_model.get("max_hp", 0)),
			int(unit_model.get("current_mp", 0)),
			int(unit_model.get("max_mp", 0)),
			int(unit_model.get("ultimate_points", 0)),
			int(unit_model.get("ultimate_points_cap", 0)),
		])
	return "\n".join(lines)

func format_effects(effects: Array) -> String:
	if effects.is_empty():
		return "-"
	var entries: Array = []
	for effect_model in effects:
		if not (effect_model is Dictionary):
			continue
		entries.append("%s(%d)" % [
			str(effect_model.get("effect_definition_id", "")),
			int(effect_model.get("remaining", 0)),
		])
	return ", ".join(entries) if not entries.is_empty() else "-"

func find_side_model(side_models: Array, side_id: String) -> Dictionary:
	for side_model in side_models:
		if side_model is Dictionary and str(side_model.get("side_id", "")) == side_id:
			return side_model
	return {}

func control_mode_for_side(side_control_modes: Dictionary, side_id: String) -> String:
	return str(side_control_modes.get(side_id, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges()
