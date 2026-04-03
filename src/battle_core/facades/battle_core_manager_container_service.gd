extends RefCounted
class_name BattleCoreManagerContainerService

const BattleCoreSessionScript := preload("res://src/battle_core/facades/battle_core_session.gd")
const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var container_factory: Callable = Callable()
var contract_helper = null
var public_snapshot_builder = null
var container_factory_owner = null

func create_session_result(session_id: String, init_payload: Dictionary) -> Dictionary:
    var compose_result = _compose_container_result()
    if not bool(compose_result.get("ok", false)):
        return {
            "session": null,
            "response": compose_result,
        }
    var container = compose_result.get("data", null)
    var battle_seed: int = int(init_payload.get("battle_seed", 0))
    var id_factory = container.service("id_factory")
    var rng_service = container.service("rng_service")
    var battle_initializer = container.service("battle_initializer")
    id_factory.reset()
    rng_service.reset(battle_seed)
    var content_index = BattleContentIndexScript.new()
    if not content_index.load_snapshot(init_payload["content_snapshot_paths"]):
        container.dispose()
        return {
            "session": null,
            "response": contract_helper.error(
                content_index.last_error_code if content_index.last_error_code != null else ErrorCodesScript.INVALID_CONTENT_SNAPSHOT,
                content_index.last_error_message if not content_index.last_error_message.is_empty() else "BattleCoreManager failed to load content snapshot"
            ),
        }
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = session_id
    battle_state.seed = battle_seed
    battle_state.rng_stream_index = rng_service.get_stream_index()
    if not battle_initializer.initialize_battle(battle_state, content_index, init_payload["battle_setup"]):
        var initializer_error_code = battle_initializer.last_error_code
        var initializer_error_message := String(battle_initializer.last_error_message)
        container.dispose()
        return {
            "session": null,
            "response": contract_helper.error(
                initializer_error_code if initializer_error_code != null else ErrorCodesScript.INVALID_BATTLE_SETUP,
                initializer_error_message if not initializer_error_message.is_empty() else "BattleCoreManager failed to initialize battle"
            ),
        }
    var session = BattleCoreSessionScript.new()
    session.session_id = session_id
    session.container = container
    session.battle_state = battle_state
    session.content_index = content_index
    var public_snapshot = public_snapshot_builder.build_public_snapshot(battle_state, content_index)
    return {
        "session": session,
        "response": contract_helper.ok({
            "session_id": session_id,
            "public_snapshot": public_snapshot,
            "prebattle_public_teams": public_snapshot.get("prebattle_public_teams", []),
        }),
    }

func run_replay_result(replay_input) -> Dictionary:
    var compose_result = _compose_container_result()
    if not bool(compose_result.get("ok", false)):
        return compose_result
    var temp_container = compose_result.get("data", null)
    var replay_runner = temp_container.service("replay_runner")
    var replay_result: Dictionary = replay_runner.run_replay_with_context(replay_input)
    var internal_replay_output = replay_result.get("replay_output", null)
    if internal_replay_output == null:
        var error_result = contract_helper.service_error(
            replay_runner,
            ErrorCodesScript.INVALID_REPLAY_INPUT,
            "BattleCoreManager failed to run replay"
        )
        temp_container.dispose()
        return error_result
    var public_snapshot = public_snapshot_builder.build_public_snapshot(internal_replay_output.final_battle_state, replay_result["content_index"])
    var replay_output = internal_replay_output.clone_without_runtime_state()
    temp_container.dispose()
    return contract_helper.ok({"replay_output": replay_output, "public_snapshot": public_snapshot})

func _compose_container_result() -> Dictionary:
    if not container_factory.is_valid():
        return contract_helper.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager requires container_factory")
    var container = container_factory.call()
    if container != null:
        return contract_helper.ok(container)
    var composer = container_factory_owner.composer if container_factory_owner != null else null
    if composer != null:
        return contract_helper.error(
            composer.last_error_code if composer.last_error_code != null else ErrorCodesScript.INVALID_COMPOSITION,
            composer.last_error_message if not composer.last_error_message.is_empty() else "BattleCoreManager failed to compose battle core container"
        )
    return contract_helper.error(ErrorCodesScript.INVALID_COMPOSITION, "BattleCoreManager failed to compose battle core container")
