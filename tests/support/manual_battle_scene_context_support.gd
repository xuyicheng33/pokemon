extends RefCounted
class_name ManualBattleSceneContextSupport

const BATTLE_SANDBOX_SCENE_PATH := "res://scenes/sandbox/BattleSandbox.tscn"
const BattleSandboxLaunchConfigScript := preload("res://src/adapters/battle_sandbox_launch_config.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")

var _launch_config_helper = BattleSandboxLaunchConfigScript.new()

func build_manual_scene_context(battle_seed = null, launch_config: Dictionary = {}) -> Dictionary:
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
		return fail(message)
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
		return fail("controller has not loaded legal actions for side %s" % side_id)
	return ResultEnvelopeHelperScript.ok(legal_actions)

func instantiate_controller_result() -> Dictionary:
	var packed_scene = load(BATTLE_SANDBOX_SCENE_PATH)
	if packed_scene == null:
		return fail("failed to load %s" % BATTLE_SANDBOX_SCENE_PATH)
	if not (packed_scene is PackedScene):
		return fail("%s must be PackedScene" % BATTLE_SANDBOX_SCENE_PATH)
	var controller = packed_scene.instantiate()
	if controller == null:
		return fail("%s instantiate returned null" % BATTLE_SANDBOX_SCENE_PATH)
	if not (controller is Node):
		return fail("%s root must be Node" % BATTLE_SANDBOX_SCENE_PATH)
	for method_name in ["bootstrap_with_config", "submit_action", "build_view_model", "get_state_snapshot", "close_runtime"]:
		if not controller.has_method(method_name):
			_free_controller(controller)
			return fail("%s missing controller method %s" % [BATTLE_SANDBOX_SCENE_PATH, method_name])
	return ResultEnvelopeHelperScript.ok(controller)

func sync_context_from_controller(context: Dictionary) -> void:
	var controller = context.get("controller", null)
	if controller == null:
		return
	var state_snapshot: Dictionary = controller.get_state_snapshot()
	for key in state_snapshot.keys():
		context[key] = state_snapshot[key]

func fail(message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(null, message)

func _free_controller(controller) -> void:
	if controller != null and is_instance_valid(controller):
		controller.free()

func _unwrap_close_result(close_envelope: Dictionary) -> Dictionary:
	if close_envelope == null:
		return fail("close_session returned null envelope")
	if bool(close_envelope.get("ok", false)):
		return ResultEnvelopeHelperScript.ok(null)
	return fail(str(close_envelope.get("error_message", "close_session failed")))
