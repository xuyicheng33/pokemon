extends RefCounted
class_name ManualBattleSceneSupport

const BATTLE_SANDBOX_SCENE_PATH := "res://scenes/sandbox/BattleSandbox.tscn"
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const BattleSandboxFirstLegalPolicyScript := preload("res://src/adapters/battle_sandbox_first_legal_policy.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _policy_port = BattleSandboxFirstLegalPolicyScript.new()

func build_manual_scene_context(_harness, battle_seed: int, launch_config: Dictionary = {}) -> Dictionary:
	var scene_result = _instantiate_controller_result()
	if not bool(scene_result.get("ok", false)):
		return scene_result
	var controller = scene_result.get("data", null)
	var normalized_config := launch_config.duplicate(true)
	if normalized_config.is_empty():
		normalized_config = _launch_config_helper.default_config()
	normalized_config["battle_seed"] = battle_seed
	var bootstrap_result = controller.bootstrap_with_config(normalized_config)
	if not bool(bootstrap_result.get("ok", false)):
		var message = str(bootstrap_result.get("error", controller.error_message if controller != null else "manual scene bootstrap failed"))
		_free_controller(controller)
		return _fail(message)
	var context = {
		"ok": true,
		"controller": controller,
		"scene_root": controller,
	}
	_sync_context_from_controller(context)
	return context

func close_context(context: Dictionary) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null:
		return {"ok": true}
	var close_result = {"ok": true}
	var manager = controller.manager
	var session_id = str(controller.session_id).strip_edges()
	if manager != null and not session_id.is_empty():
		close_result = _unwrap_close_result(manager.close_session(session_id))
	if manager != null and manager.has_method("dispose"):
		manager.dispose()
	controller.session_id = ""
	controller.manager = null
	_free_controller(controller)
	return close_result

func get_legal_actions(context: Dictionary, side_id: String) -> Dictionary:
	var legal_actions_by_side: Dictionary = context.get("legal_actions_by_side", {})
	var legal_actions = legal_actions_by_side.get(side_id, null)
	if legal_actions == null:
		return _fail("controller has not loaded legal actions for side %s" % side_id)
	return {"ok": true, "data": legal_actions}

func run_hotseat_turn(context: Dictionary, p1_selected_action: Dictionary, p2_selected_action: Dictionary) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null:
		return _fail("run_hotseat_turn requires controller context")
	var cursor_before = int(context.get("event_log_cursor", 0))
	var p1_result = controller.submit_selected_action(p1_selected_action)
	if not bool(p1_result.get("ok", false)):
		return _fail(str(p1_result.get("error", "controller submit_selected_action(P1) failed")))
	_sync_context_from_controller(context)
	var p2_result = controller.submit_selected_action(p2_selected_action)
	if not bool(p2_result.get("ok", false)):
		return _fail(str(p2_result.get("error", "controller submit_selected_action(P2) failed")))
	_sync_context_from_controller(context)
	return {
		"ok": true,
		"public_snapshot": context.get("public_snapshot", {}),
		"event_delta": context.get("last_event_delta", []),
		"event_log_cursor_before": cursor_before,
		"event_log_cursor_after": int(context.get("event_log_cursor", cursor_before)),
	}

func run_to_battle_end(context: Dictionary, max_turns: int = 64) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null:
		return _fail("run_to_battle_end requires controller context")
	var max_command_steps = max(max_turns * 2 + 2, 4)
	var command_steps = 0
	while not _battle_finished(context):
		if command_steps >= max_command_steps:
			return _fail("auto battle exceeded command step limit %d" % max_command_steps)
		var legal_actions_result = _current_side_legal_actions_result(context)
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
		var submit_result = controller.submit_selected_action(auto_action_result.get("data", {}))
		if not bool(submit_result.get("ok", false)):
			return _fail(str(submit_result.get("error", "controller submit_selected_action(auto) failed")))
		_sync_context_from_controller(context)
		command_steps += 1
	var battle_result = context.get("public_snapshot", {}).get("battle_result", null)
	return {
		"ok": true,
		"battle_result": battle_result.duplicate(true) if battle_result is Dictionary else battle_result,
		"turn_index": current_turn_index(context),
		"event_log_cursor": int(context.get("event_log_cursor", 0)),
		"command_steps": command_steps,
		"battle_summary": context.get("battle_summary", {}).duplicate(true),
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

func _current_side_legal_actions_result(context: Dictionary) -> Dictionary:
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
	_sync_context_from_controller(context)
	legal_actions = context.get("legal_actions_by_side", {}).get(side_id, null)
	if legal_actions == null:
		return _fail("controller did not keep legal actions for side %s after refresh" % side_id)
	return {"ok": true, "side_id": side_id, "data": legal_actions}

func _battle_finished(context: Dictionary) -> bool:
	var battle_result = context.get("public_snapshot", {}).get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func _instantiate_controller_result() -> Dictionary:
	var packed_scene = load(BATTLE_SANDBOX_SCENE_PATH)
	if packed_scene == null:
		return _fail("failed to load %s" % BATTLE_SANDBOX_SCENE_PATH)
	if not (packed_scene is PackedScene):
		return _fail("%s must be PackedScene" % BATTLE_SANDBOX_SCENE_PATH)
	var controller = packed_scene.instantiate()
	if controller == null:
		return _fail("%s instantiate returned null" % BATTLE_SANDBOX_SCENE_PATH)
	if not (controller is Node):
		return _fail("%s root must be Node" % BATTLE_SANDBOX_SCENE_PATH)
	for method_name in ["bootstrap_with_config", "submit_selected_action", "build_view_model", "get_state_snapshot"]:
		if not controller.has_method(method_name):
			_free_controller(controller)
			return _fail("%s missing controller method %s" % [BATTLE_SANDBOX_SCENE_PATH, method_name])
	return {"ok": true, "data": controller}

func _sync_context_from_controller(context: Dictionary) -> void:
	var controller = context.get("controller", null)
	if controller == null:
		return
	var state_snapshot: Dictionary = controller.get_state_snapshot()
	for key in state_snapshot.keys():
		context[key] = state_snapshot[key]
	context["manager"] = controller.manager

func _free_controller(controller) -> void:
	if controller != null and is_instance_valid(controller):
		controller.free()

func _unwrap_close_result(close_envelope: Dictionary) -> Dictionary:
	if close_envelope == null:
		return _fail("close_session returned null envelope")
	if bool(close_envelope.get("ok", false)):
		return {"ok": true}
	return _fail(str(close_envelope.get("error_message", "close_session failed")))

func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
