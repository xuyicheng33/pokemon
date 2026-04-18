extends RefCounted
class_name SandboxViewFormatHelper

const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()

func format_status_text(controller, current_view_model: Dictionary) -> String:
	if bool(current_view_model.get("replay_mode", false)):
		var replay_result_text := ""
		if not str(controller.battle_summary.get("result_type", "")).strip_edges().is_empty() \
		or not str(controller.battle_summary.get("reason", "")).strip_edges().is_empty():
			replay_result_text = " | result=%s/%s" % [
				str(controller.battle_summary.get("result_type", "")),
				str(controller.battle_summary.get("reason", "")),
			]
		return "config=demo=%s | %s | phase=%s | field=%s | mode=read_only%s" % [
			controller.demo_profile,
			format_replay_turn_label(current_view_model),
			str(current_view_model.get("phase", "")),
			value_or_dash(str(current_view_model.get("field_id", "")).strip_edges()),
			replay_result_text,
		]
	var field_id = str(current_view_model.get("field_id", "")).strip_edges()
	var current_side = str(current_view_model.get("current_side_to_select", "")).strip_edges()
	var current_control_mode = "-"
	if not current_side.is_empty():
		current_control_mode = control_mode_for_side(controller.side_control_modes, current_side)
	var policy_status = format_policy_status(controller.side_control_modes, current_side, has_battle_result(controller.public_snapshot))
	var config_text = "demo=%s" % controller.demo_profile if controller.is_demo_mode else "%s/%s" % [
		control_mode_for_side(controller.side_control_modes, "P1"),
		control_mode_for_side(controller.side_control_modes, "P2"),
	]
	var result_text = ""
	if not str(controller.battle_summary.get("result_type", "")).strip_edges().is_empty() \
	or not str(controller.battle_summary.get("reason", "")).strip_edges().is_empty():
		result_text = " | result=%s/%s" % [
			str(controller.battle_summary.get("result_type", "")),
			str(controller.battle_summary.get("reason", "")),
		]
	return "config=%s | turn=%d | phase=%s | field=%s | current=%s(%s) | policy=%s%s" % [
		config_text,
		int(current_view_model.get("turn_index", 0)),
		str(current_view_model.get("phase", "")),
		field_id if not field_id.is_empty() else "-",
		current_side if not current_side.is_empty() else "-",
		current_control_mode,
		policy_status,
		result_text,
	]

func format_config_status_text(controller) -> String:
	if controller.is_demo_mode:
		return "当前配置：demo=%s（回放浏览态，只读浏览，启动控件已禁用）" % controller.demo_profile
	return "当前配置：%s" % _launch_config_helper.build_config_summary(controller.launch_config)

func format_battle_summary_text(battle_summary: Dictionary) -> String:
	if battle_summary.is_empty():
		return "对局摘要: -"
	return "对局摘要: matchup=%s | seed=%d | P1=%s | P2=%s | winner=%s | reason=%s | result=%s | turn=%d | events=%d | commands=%d" % [
		value_or_dash(str(battle_summary.get("matchup_id", "")).strip_edges()),
		int(battle_summary.get("battle_seed", 0)),
		value_or_dash(str(battle_summary.get("p1_control_mode", "")).strip_edges()),
		value_or_dash(str(battle_summary.get("p2_control_mode", "")).strip_edges()),
		value_or_dash(str(battle_summary.get("winner_side_id", "")).strip_edges()),
		value_or_dash(str(battle_summary.get("reason", "")).strip_edges()),
		value_or_dash(str(battle_summary.get("result_type", "")).strip_edges()),
		int(battle_summary.get("turn_index", 0)),
		int(battle_summary.get("event_log_cursor", 0)),
		int(battle_summary.get("command_steps", 0)),
	]

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

func format_pending_text(current_view_model: Dictionary, battle_summary: Dictionary) -> String:
	if bool(current_view_model.get("replay_mode", false)):
		var replay_frame: Dictionary = current_view_model.get("replay_current_frame", {})
		return "只读回放: events=%d..%d | battle_finished=%s" % [
			int(replay_frame.get("event_from", 0)),
			int(replay_frame.get("event_to", 0)),
			"yes" if bool(replay_frame.get("battle_finished", false)) else "no",
		]
	var pending_summaries: Array = current_view_model.get("pending_commands", [])
	var command_steps := int(battle_summary.get("command_steps", 0))
	if pending_summaries.is_empty():
		if command_steps <= 0:
			return "已提交指令: -"
		return "已提交指令: - | commands=%d" % command_steps
	var entries: Array = []
	for pending_summary in pending_summaries:
		if not (pending_summary is Dictionary):
			continue
		var entry = "%s:%s" % [
			str(pending_summary.get("side_id", "")),
			str(pending_summary.get("command_type", "")),
		]
		var skill_id = str(pending_summary.get("skill_id", "")).strip_edges()
		var target_public_id = str(pending_summary.get("target_public_id", "")).strip_edges()
		if not skill_id.is_empty():
			entry += " skill=%s" % skill_id
		if not target_public_id.is_empty():
			entry += " target=%s" % target_public_id
		entries.append(entry)
	return "已提交指令: %s | commands=%d" % [" | ".join(entries), command_steps]

func format_action_header(controller, current_view_model: Dictionary) -> String:
	if controller._startup_failed:
		return "场景初始化失败"
	if controller.is_demo_mode:
		return "回放浏览态 | %s" % format_replay_turn_label(current_view_model)
	if has_battle_result(controller.public_snapshot):
		return "结算态 | winner=%s | reason=%s" % [
			value_or_dash(str(controller.battle_summary.get("winner_side_id", "")).strip_edges()),
			value_or_dash(str(controller.battle_summary.get("reason", "")).strip_edges()),
		]
	var side_id = str(current_view_model.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		return "等待下一步"
	var legal_actions: Dictionary = current_view_model.get("legal_actions_by_side", {}).get(side_id, {})
	var actor_public_id = str(legal_actions.get("actor_public_id", "")).strip_edges()
	return "当前待选边: %s | actor=%s | control=%s | policy=%s" % [
		side_id,
		actor_public_id if not actor_public_id.is_empty() else "-",
		control_mode_for_side(controller.side_control_modes, side_id),
		format_policy_status(controller.side_control_modes, side_id, false),
	]

func format_policy_status(side_control_modes: Dictionary, current_side: String, battle_finished: bool) -> String:
	var policy_sides: Array = []
	for side_id in BattleSandboxLaunchConfigScript.SIDE_IDS:
		if is_policy_side(side_control_modes, side_id):
			policy_sides.append(side_id)
	if policy_sides.is_empty():
		return "disabled"
	if battle_finished:
		return "stopped(%s)" % ",".join(policy_sides)
	if not current_side.is_empty() and is_policy_side(side_control_modes, current_side):
		return "advancing(%s)" % current_side
	return "standby(%s)" % ",".join(policy_sides)

func find_side_model(side_models: Array, side_id: String) -> Dictionary:
	for side_model in side_models:
		if side_model is Dictionary and str(side_model.get("side_id", "")) == side_id:
			return side_model
	return {}

func control_mode_for_side(side_control_modes: Dictionary, side_id: String) -> String:
	return str(side_control_modes.get(side_id, BattleSandboxLaunchConfigScript.CONTROL_MODE_MANUAL)).strip_edges()

func is_policy_side(side_control_modes: Dictionary, side_id: String) -> bool:
	return _launch_config_helper.is_policy_control_mode(control_mode_for_side(side_control_modes, side_id))

func has_battle_result(public_snapshot: Dictionary) -> bool:
	var battle_result = public_snapshot.get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func value_or_dash(value: String) -> String:
	return value if not value.is_empty() else "-"

func format_event_header_text(controller, current_view_model: Dictionary) -> String:
	if not controller.is_demo_mode:
		return "Recent Events"
	var replay_frame: Dictionary = current_view_model.get("replay_current_frame", {})
	return "Replay Events | turn=%d | events=%d..%d" % [
		int(replay_frame.get("turn_index", 0)),
		int(replay_frame.get("event_from", 0)),
		int(replay_frame.get("event_to", 0)),
	]

func format_replay_turn_label(current_view_model: Dictionary) -> String:
	var replay_frame_count := int(current_view_model.get("replay_frame_count", 0))
	if replay_frame_count <= 0:
		return "回合 - | frame 0/0 | events 0..0"
	var replay_frame_index := int(current_view_model.get("replay_frame_index", 0))
	var replay_frame: Dictionary = current_view_model.get("replay_current_frame", {})
	return "回合 %d | frame %d/%d | events %d..%d" % [
		int(replay_frame.get("turn_index", 0)),
		replay_frame_index + 1,
		replay_frame_count,
		int(replay_frame.get("event_from", 0)),
		int(replay_frame.get("event_to", 0)),
	]
