extends RefCounted
class_name ManualBattleSceneDriveSupport

const BattleSandboxFirstLegalPolicyScript := preload("res://src/adapters/battle_sandbox_first_legal_policy.gd")

var _policy_port = BattleSandboxFirstLegalPolicyScript.new()

func run_hotseat_turn(context_support, context: Dictionary, p1_selected_action: Dictionary, p2_selected_action: Dictionary) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null:
		return _fail("run_hotseat_turn requires controller context")
	var cursor_before = int(context.get("event_log_cursor", 0))
	var p1_result = controller.submit_action(p1_selected_action)
	if not bool(p1_result.get("ok", false)):
		return _fail(str(p1_result.get("error", "controller submit_action(P1) failed")))
	context_support.sync_context_from_controller(context)
	var p2_result = controller.submit_action(p2_selected_action)
	if not bool(p2_result.get("ok", false)):
		return _fail(str(p2_result.get("error", "controller submit_action(P2) failed")))
	context_support.sync_context_from_controller(context)
	return {
		"ok": true,
		"public_snapshot": context.get("public_snapshot", {}),
		"event_delta": context.get("last_event_delta", []),
		"event_log_cursor_before": cursor_before,
		"event_log_cursor_after": int(context.get("event_log_cursor", cursor_before)),
	}

func run_to_battle_end(context_support, context: Dictionary, max_turns: int = 64) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null:
		return _fail("run_to_battle_end requires controller context")
	var max_command_steps = max(max_turns * 2 + 2, 4)
	var command_steps = 0
	while not _battle_finished(context):
		if command_steps >= max_command_steps:
			return _fail("auto battle exceeded command step limit %d" % max_command_steps)
		var legal_actions_result = _current_side_legal_actions_result(context_support, context)
		if not bool(legal_actions_result.get("ok", false)):
			return legal_actions_result
		var auto_action_result = _policy_port.select_action_result(
			legal_actions_result.get("data", null),
			context.get("public_snapshot", {}).duplicate(true),
			{
				"launch_config": context.get("launch_config", {}).duplicate(true),
				"side_control_modes": context.get("side_control_modes", {}).duplicate(true),
				"current_side_to_select": context.get("current_side_to_select", ""),
				"event_log_cursor": int(context.get("event_log_cursor", 0)),
			}
		)
		if not bool(auto_action_result.get("ok", false)):
			return _fail(str(auto_action_result.get("error", "auto battle failed to pick action")))
		var submit_result = controller.submit_action(auto_action_result.get("data", {}))
		if not bool(submit_result.get("ok", false)):
			return _fail(str(submit_result.get("error", "controller submit_action(auto) failed")))
		context_support.sync_context_from_controller(context)
		command_steps += 1
	var battle_result = context.get("public_snapshot", {}).get("battle_result", null)
	var battle_summary: Dictionary = context.get("battle_summary", {}).duplicate(true)
	return {
		"ok": true,
		"battle_result": battle_result.duplicate(true) if battle_result is Dictionary else battle_result,
		"turn_index": current_turn_index(context),
		"event_log_cursor": int(context.get("event_log_cursor", 0)),
		"command_steps": int(battle_summary.get("command_steps", command_steps)),
		"battle_summary": battle_summary,
	}

func build_view_model(context: Dictionary) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null or not controller.has_method("build_view_model"):
		return {}
	var view_model = controller.build_view_model()
	return view_model if typeof(view_model) == TYPE_DICTIONARY else {}

func validate_view_model_renderable(view_model: Dictionary) -> String:
	if typeof(view_model) != TYPE_DICTIONARY:
		return "view_model must be Dictionary"
	if str(view_model.get("battle_id", "")).is_empty():
		return "view_model missing battle_id"
	if typeof(view_model.get("turn_index", null)) != TYPE_INT:
		return "view_model missing integer turn_index"
	if typeof(view_model.get("phase", null)) != TYPE_STRING:
		return "view_model missing phase"
	if typeof(view_model.get("sides", null)) != TYPE_ARRAY:
		return "view_model missing sides"
	if typeof(view_model.get("launch_config", null)) != TYPE_DICTIONARY:
		return "view_model missing launch_config"
	for side_model in view_model.get("sides", []):
		if typeof(side_model) != TYPE_DICTIONARY:
			return "view_model side must be Dictionary"
		if str(side_model.get("side_id", "")).is_empty():
			return "view_model side missing side_id"
	return ""

func current_turn_index(context: Dictionary) -> int:
	var public_snapshot: Dictionary = context.get("public_snapshot", {})
	return max(int(public_snapshot.get("turn_index", 1)), 1)

func _current_side_legal_actions_result(context_support, context: Dictionary) -> Dictionary:
	var side_id = str(context.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		return _fail("manual scene is not waiting for side selection")
	var legal_actions = context.get("legal_actions_by_side", {}).get(side_id, null)
	if legal_actions != null:
		return {"ok": true, "side_id": side_id, "data": legal_actions}
	var controller = context.get("controller", null)
	if controller == null or not controller.has_method("fetch_legal_actions_for_side"):
		return _fail("controller cannot refresh legal actions for side %s" % side_id)
	var refresh_result = controller.fetch_legal_actions_for_side(side_id)
	if not bool(refresh_result.get("ok", false)):
		return _fail(str(refresh_result.get("error", "fetch_legal_actions_for_side(%s) failed" % side_id)))
	context_support.sync_context_from_controller(context)
	legal_actions = context.get("legal_actions_by_side", {}).get(side_id, null)
	if legal_actions == null:
		return _fail("controller did not keep legal actions for side %s after refresh" % side_id)
	return {"ok": true, "side_id": side_id, "data": legal_actions}

func _battle_finished(context: Dictionary) -> bool:
	var battle_result = context.get("public_snapshot", {}).get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
