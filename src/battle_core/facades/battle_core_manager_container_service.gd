extends RefCounted
class_name BattleCoreManagerContainerService

const BattleCoreSessionScript := preload("res://src/battle_core/facades/battle_core_session.gd")
const BattleCoreManagerContractHelperScript := preload("res://src/battle_core/facades/battle_core_manager_contract_helper.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const REQUIRED_CONTAINER_SERVICES := [
	"id_factory",
	"rng_service",
	"battle_initializer",
	"content_snapshot_cache",
]

var container_factory: Callable = Callable()
var public_snapshot_builder: BattleCorePublicSnapshotBuilder = null
var container_factory_owner: RefCounted = null

func create_session_result(session_id: String, init_payload: Dictionary) -> Dictionary:
	var compose_result = _compose_container_result()
	if not bool(compose_result.get("ok", false)):
		return compose_result
	var container = compose_result.get("data", null)
	var services_result := _required_services_result(container)
	if not bool(services_result.get("ok", false)):
		if container != null and container.has_method("dispose"):
			container.dispose()
		return services_result
	var services: Dictionary = services_result.get("data", {})
	var battle_seed: int = int(init_payload.get("battle_seed", 0))
	var id_factory = services.get("id_factory", null)
	var rng_service = services.get("rng_service", null)
	var battle_initializer = services.get("battle_initializer", null)
	var content_snapshot_cache = services.get("content_snapshot_cache", null)
	id_factory.reset()
	rng_service.reset(battle_seed)
	var content_index_result: Dictionary = content_snapshot_cache.build_content_index(init_payload["content_snapshot_paths"])
	if not bool(content_index_result.get("ok", false)):
		container.dispose()
		return BattleCoreManagerContractHelperScript.error(
			content_index_result.get("error_code", ErrorCodesScript.INVALID_CONTENT_SNAPSHOT),
			String(content_index_result.get("error_message", "BattleCoreManager failed to load content snapshot"))
		)
	var content_index = content_index_result.get("content_index", null)
	if content_index == null:
		container.dispose()
		return BattleCoreManagerContractHelperScript.error(
			ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
			"BattleCoreManager content_snapshot_cache returned null content_index"
		)
	var battle_state = BattleStateScript.new()
	battle_state.battle_id = session_id
	battle_state.seed = battle_seed
	battle_state.rng_stream_index = rng_service.get_stream_index()
	if not battle_initializer.initialize_battle(battle_state, content_index, init_payload["battle_setup"]):
		var initializer_error_state: Dictionary = battle_initializer.error_state()
		var initializer_error_code = initializer_error_state.get("code", null)
		var initializer_error_message := String(initializer_error_state.get("message", ""))
		container.dispose()
		return BattleCoreManagerContractHelperScript.error(
			initializer_error_code if initializer_error_code != null else ErrorCodesScript.INVALID_BATTLE_SETUP,
			initializer_error_message if not initializer_error_message.is_empty() else "BattleCoreManager failed to initialize battle"
		)
	var session = BattleCoreSessionScript.new()
	session.session_id = session_id
	session.configure_runtime(container, battle_state, content_index)
	var runtime_error = BattleCoreManagerContractHelperScript.validate_session_runtime_result(session)
	if runtime_error != null:
		session.dispose()
		return runtime_error
	return BattleCoreManagerContractHelperScript.ok({
		"session": session,
		"session_id": session_id,
	})

func run_replay_result(replay_input) -> Dictionary:
	var compose_result = _compose_container_result()
	if not bool(compose_result.get("ok", false)):
		return compose_result
	var temp_container = compose_result.get("data", null)
	var replay_runner = temp_container.service("replay_runner")
	var replay_result: Dictionary = replay_runner.run_replay_with_context(replay_input)
	var internal_replay_output = replay_result.get("replay_output", null)
	if internal_replay_output == null:
		var error_result = BattleCoreManagerContractHelperScript.service_error(
			replay_runner,
			ErrorCodesScript.INVALID_REPLAY_INPUT,
			"BattleCoreManager failed to run replay"
		)
		temp_container.dispose()
		return error_result
	if not bool(internal_replay_output.succeeded):
		var failure_result := BattleCoreManagerContractHelperScript.service_error(
			replay_runner,
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			_describe_replay_failure(internal_replay_output)
		)
		temp_container.dispose()
		return failure_result
	var final_battle_state = internal_replay_output.final_battle_state
	var content_index = replay_result.get("content_index", null)
	if final_battle_state == null or content_index == null:
		var invalid_replay_result := BattleCoreManagerContractHelperScript.error(
			ErrorCodesScript.INVALID_STATE_CORRUPTION,
			"BattleCoreManager replay succeeded flag requires final_battle_state and content_index"
		)
		temp_container.dispose()
		return invalid_replay_result
	var public_snapshot = _resolve_final_replay_public_snapshot(
		internal_replay_output,
		final_battle_state,
		content_index
	)
	var replay_output = internal_replay_output.clone_without_runtime_state()
	temp_container.dispose()
	return BattleCoreManagerContractHelperScript.ok({"replay_output": replay_output, "public_snapshot": public_snapshot})

func _describe_replay_failure(replay_output: ReplayOutput) -> String:
	if replay_output == null:
		return "BattleCoreManager replay returned null replay_output"
	if not String(replay_output.failure_message).is_empty():
		return String(replay_output.failure_message)
	var battle_result = replay_output.battle_result
	if battle_result == null:
		return "BattleCoreManager replay returned invalid battle_result"
	if not bool(battle_result.finished):
		return "BattleCoreManager replay did not complete"
	var result_type := String(battle_result.result_type)
	var reason := String(battle_result.reason)
	if result_type.is_empty() or reason.is_empty():
		return "BattleCoreManager replay returned invalid battle_result"
	if result_type == "win" and battle_result.winner_side_id == null:
		return "BattleCoreManager replay returned invalid battle_result"
	if (result_type == "draw" or result_type == "no_winner") and battle_result.winner_side_id != null:
		return "BattleCoreManager replay returned invalid battle_result"
	return "BattleCoreManager replay log schema validation failed"

func _resolve_final_replay_public_snapshot(internal_replay_output: ReplayOutput, final_battle_state: BattleState, content_index: BattleContentIndex) -> Dictionary:
	if internal_replay_output != null:
		var turn_timeline = internal_replay_output.turn_timeline
		if turn_timeline is Array and not turn_timeline.is_empty():
			var last_frame = turn_timeline[turn_timeline.size() - 1]
			if last_frame is Dictionary and last_frame.get("public_snapshot", null) is Dictionary:
				return last_frame.get("public_snapshot", {}).duplicate(true)
	return public_snapshot_builder.build_public_snapshot(final_battle_state, content_index)

func _compose_container_result() -> Dictionary:
	if not container_factory.is_valid():
		return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager requires container_factory")
	var container = container_factory.call()
	if container != null:
		return BattleCoreManagerContractHelperScript.ok(container)
	if container_factory_owner != null and container_factory_owner.has_method("error_state"):
		var composer_error_state: Dictionary = container_factory_owner.error_state()
		return BattleCoreManagerContractHelperScript.error(
			composer_error_state.get("code", ErrorCodesScript.INVALID_COMPOSITION),
			String(composer_error_state.get("message", "BattleCoreManager failed to compose battle core container"))
		)
	return BattleCoreManagerContractHelperScript.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager failed to compose battle core container")

func _required_services_result(container: BattleCoreContainer) -> Dictionary:
	var resolved_services: Dictionary = {}
	for service_name in REQUIRED_CONTAINER_SERVICES:
		var service = container.service(String(service_name))
		if service == null:
			return BattleCoreManagerContractHelperScript.error(
				ErrorCodesScript.INVALID_COMPOSITION,
				"BattleCoreManager missing dependency: %s" % String(service_name)
			)
		resolved_services[String(service_name)] = service
	return BattleCoreManagerContractHelperScript.ok(resolved_services)
