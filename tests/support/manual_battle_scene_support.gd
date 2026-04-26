extends RefCounted
class_name ManualBattleSceneSupport

const BATTLE_SANDBOX_SCENE_PATH := "res://scenes/sandbox/BattleSandbox.tscn"
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const BattleSandboxFirstLegalPolicyScript := preload("res://src/adapters/battle_sandbox_first_legal_policy.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()
var _policy_port = BattleSandboxFirstLegalPolicyScript.new()

func build_manual_scene_context(_harness = null, battle_seed = null, launch_config: Dictionary = {}) -> Dictionary:
	var scene_result = instantiate_controller_result()
	if not bool(scene_result.get("ok", false)):
		return scene_result
	var controller = scene_result.get("data", null)
	var normalized_config: Dictionary = launch_config.duplicate(true)
	if normalized_config.is_empty():
		normalized_config = _launch_config_helper.default_config()
	if battle_seed != null:
		normalized_config["battle_seed"] = battle_seed
	var bootstrap_result = controller.bootstrap_with_config(normalized_config)
	if not bool(bootstrap_result.get("ok", false)):
		var message = str(bootstrap_result.get("error_message", "manual scene bootstrap failed"))
		_free_controller(controller)
		return _fail(message)
	var context = {
		"ok": true,
		"data": {
			"controller": controller,
			"scene_root": controller,
		},
		"error_code": null,
		"error_message": null,
		"controller": controller,
		"scene_root": controller,
	}
	sync_context_from_controller(context)
	return context

func close_context(context: Dictionary) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null:
		return ResultEnvelopeHelperScript.ok(null)
	var close_result = _unwrap_close_result(controller.close_runtime())
	_free_controller(controller)
	return close_result

func get_legal_actions(context: Dictionary, side_id: String) -> Dictionary:
	var legal_actions_by_side: Dictionary = context.get("legal_actions_by_side", {})
	var legal_actions = legal_actions_by_side.get(side_id, null)
	if legal_actions == null:
		return _fail("controller has not loaded legal actions for side %s" % side_id)
	return ResultEnvelopeHelperScript.ok(legal_actions)

func instantiate_controller_result() -> Dictionary:
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
	for method_name in ["bootstrap_with_config", "submit_action", "build_view_model", "get_state_snapshot", "close_runtime"]:
		if not controller.has_method(method_name):
			_free_controller(controller)
			return _fail("%s missing controller method %s" % [BATTLE_SANDBOX_SCENE_PATH, method_name])
	return ResultEnvelopeHelperScript.ok(controller)

func sync_context_from_controller(context: Dictionary) -> void:
	var controller = context.get("controller", null)
	if controller == null:
		return
	var state_snapshot: Dictionary = controller.get_state_snapshot()
	for key in state_snapshot.keys():
		context[key] = state_snapshot[key]

func run_hotseat_turn(context: Dictionary, p1_selected_action: Dictionary, p2_selected_action: Dictionary) -> Dictionary:
	var controller = context.get("controller", null)
	if controller == null:
		return _fail("run_hotseat_turn requires controller context")
	var cursor_before = int(context.get("event_log_cursor", 0))
	var p1_result = controller.submit_action(p1_selected_action)
	if not bool(p1_result.get("ok", false)):
		return _fail(str(p1_result.get("error_message", "controller submit_action(P1) failed")))
	sync_context_from_controller(context)
	var p2_result = controller.submit_action(p2_selected_action)
	if not bool(p2_result.get("ok", false)):
		return _fail(str(p2_result.get("error_message", "controller submit_action(P2) failed")))
	sync_context_from_controller(context)
	return {
		"ok": true,
		"data": null,
		"error_code": null,
		"error_message": null,
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
			return _fail(str(auto_action_result.get("error_message", "auto battle failed to pick action")))
		var submit_result = controller.submit_action(auto_action_result.get("data", {}))
		if not bool(submit_result.get("ok", false)):
			return _fail(str(submit_result.get("error_message", "controller submit_action(auto) failed")))
		sync_context_from_controller(context)
		command_steps += 1
	var battle_result = context.get("public_snapshot", {}).get("battle_result", null)
	var battle_summary: Dictionary = context.get("battle_summary", {}).duplicate(true)
	return {
		"ok": true,
		"data": null,
		"error_code": null,
		"error_message": null,
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

func _current_side_legal_actions_result(context: Dictionary) -> Dictionary:
	var side_id = str(context.get("current_side_to_select", "")).strip_edges()
	if side_id.is_empty():
		return _fail("manual scene is not waiting for side selection")
	var legal_actions = context.get("legal_actions_by_side", {}).get(side_id, null)
	if legal_actions != null:
		var legal_actions_result := ResultEnvelopeHelperScript.ok(legal_actions)
		legal_actions_result["side_id"] = side_id
		return legal_actions_result
	var controller = context.get("controller", null)
	if controller == null or not controller.has_method("fetch_legal_actions_for_side"):
		return _fail("controller cannot refresh legal actions for side %s" % side_id)
	var refresh_result = controller.fetch_legal_actions_for_side(side_id)
	if not bool(refresh_result.get("ok", false)):
		return _fail(str(refresh_result.get("error_message", "fetch_legal_actions_for_side(%s) failed" % side_id)))
	sync_context_from_controller(context)
	legal_actions = context.get("legal_actions_by_side", {}).get(side_id, null)
	if legal_actions == null:
		return _fail("controller did not keep legal actions for side %s after refresh" % side_id)
	var refresh_result_envelope := ResultEnvelopeHelperScript.ok(legal_actions)
	refresh_result_envelope["side_id"] = side_id
	return refresh_result_envelope

func _battle_finished(context: Dictionary) -> bool:
	var battle_result = context.get("public_snapshot", {}).get("battle_result", null)
	return battle_result is Dictionary and bool(battle_result.get("finished", false))

func _free_controller(controller) -> void:
	if controller != null and is_instance_valid(controller):
		controller.free()

func _unwrap_close_result(close_envelope: Dictionary) -> Dictionary:
	if close_envelope == null:
		return _fail("close_session returned null envelope")
	if bool(close_envelope.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(null)
	return _fail(str(close_envelope.get("error_message", "close_session failed")))

func _fail(message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(null, message)
