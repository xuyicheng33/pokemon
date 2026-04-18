extends RefCounted
class_name ReplayRunnerExecutionContextBuilder

const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

func build_context(replay_input, content_snapshot_cache, id_factory, rng_service, battle_initializer) -> Dictionary:
	id_factory.reset()
	var content_index_result = content_snapshot_cache.build_content_index(replay_input.content_snapshot_paths)
	if not bool(content_index_result.get("ok", false)):
		return {
			"ok": false,
			"content_index": null,
			"battle_state": null,
			"max_turn_index": 0,
			"error_code": content_index_result.get("error_code", ErrorCodesScript.INVALID_CONTENT_SNAPSHOT),
			"error_message": String(content_index_result.get("error_message", "ReplayRunner failed to load content snapshot")),
		}
	var content_index = content_index_result.get("content_index", null)
	rng_service.reset(replay_input.battle_seed)
	var battle_state = BattleStateScript.new()
	battle_state.battle_id = id_factory.next_id("battle")
	battle_state.seed = replay_input.battle_seed
	battle_state.rng_stream_index = rng_service.get_stream_index()
	if not battle_initializer.initialize_battle(battle_state, content_index, replay_input.battle_setup):
		var initializer_error_state: Dictionary = battle_initializer.error_state()
		return {
			"ok": false,
			"content_index": content_index,
			"battle_state": null,
			"max_turn_index": 0,
			"error_code": initializer_error_state.get("code", ErrorCodesScript.INVALID_BATTLE_SETUP),
			"error_message": String(initializer_error_state.get("message", "ReplayRunner failed to initialize battle")),
		}
	battle_state.rebuild_indexes()
	return {
		"ok": true,
		"content_index": content_index,
		"battle_state": battle_state,
		"max_turn_index": battle_state.max_turn if battle_state.max_turn > 0 else battle_state.turn_index,
		"error_code": null,
		"error_message": "",
	}
