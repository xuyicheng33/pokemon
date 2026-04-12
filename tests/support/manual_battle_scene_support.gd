extends RefCounted
class_name ManualBattleSceneSupport

const BATTLE_SANDBOX_SCENE_PATH := "res://scenes/sandbox/BattleSandbox.tscn"

func build_manual_scene_context(_harness, battle_seed: int) -> Dictionary:
	var scene_result := _instantiate_controller_result()
	if not bool(scene_result.get("ok", false)):
		return scene_result
	var controller = scene_result.get("data", null)
	var bootstrap_result = controller.bootstrap_manual_mode(battle_seed)
	if not bool(bootstrap_result.get("ok", false)):
		var message := str(bootstrap_result.get("error", controller.error_message if controller != null else "manual scene bootstrap failed"))
		_free_controller(controller)
		return _fail(message)
	var context := {
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
	var close_result := {"ok": true}
	var manager = controller.manager
	var session_id := str(controller.session_id).strip_edges()
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
	var cursor_before := int(context.get("event_log_cursor", 0))
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
	for side_model in view_model.get("sides", []):
		if typeof(side_model) != TYPE_DICTIONARY:
			return "view_model side must be Dictionary"
		if str(side_model.get("side_id", "")).is_empty():
			return "view_model side missing side_id"
	return ""

func current_turn_index(context: Dictionary) -> int:
	var public_snapshot: Dictionary = context.get("public_snapshot", {})
	return max(int(public_snapshot.get("turn_index", 1)), 1)

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
	for method_name in ["bootstrap_manual_mode", "submit_selected_action", "build_view_model", "get_state_snapshot"]:
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
