extends RefCounted
class_name PlayerBattleSession

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const BattleCoreManagerScript := preload("res://src/battle_core/facades/battle_core_manager.gd")
const SampleBattleFactoryScript := preload("res://src/dev_kit/sample_battle/sample_battle_factory.gd")
const PlayerDefaultPolicyScript := preload("res://src/adapters/player/player_default_policy.gd")
const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const ResultEnvelopeHelperScript := preload("res://src/shared/result_envelope_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

const PRIMARY_SIDE_ID := "P1"
const SECONDARY_SIDE_ID := "P2"
const SIDE_ORDER := [PRIMARY_SIDE_ID, SECONDARY_SIDE_ID]
const DEFAULT_BATTLE_SEED := 9101

var session_id: String = ""
var current_snapshot_data: Dictionary = {}
var pending_p1_command: Dictionary = {}
var battle_finished: bool = false
var default_policy: PlayerDefaultPolicy = null

var _manager = null
var _composer = null
var _sample_factory = null
var _owns_manager: bool = false
var _selection_adapter: PlayerSelectionAdapter = PlayerSelectionAdapterScript.new()
var _legal_actions_by_side: Dictionary = {}
var _closed: bool = false

func _init(manager_ref: Variant = null) -> void:
	default_policy = PlayerDefaultPolicyScript.new()
	if manager_ref == null:
		_owns_manager = true
	else:
		_manager = manager_ref
		_owns_manager = false

func start(matchup_id: String, battle_seed: int) -> Dictionary:
	if _closed:
		return _error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "PlayerBattleSession.start invoked on closed session")
	var normalized_matchup_id := str(matchup_id).strip_edges()
	if normalized_matchup_id.is_empty():
		return _error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "PlayerBattleSession.start requires non-empty matchup_id")
	if _owns_manager and _manager == null:
		var compose_error := _compose_manager()
		if not compose_error.is_empty():
			return _error(ErrorCodesScript.INVALID_COMPOSITION, compose_error)
	if _manager == null:
		return _error(ErrorCodesScript.INVALID_COMPOSITION, "PlayerBattleSession.start missing manager")
	if _sample_factory == null:
		_sample_factory = SampleBattleFactoryScript.new()
	if _sample_factory == null:
		return _error(ErrorCodesScript.INVALID_COMPOSITION, "PlayerBattleSession.start failed to construct sample factory")
	var setup_result: Dictionary = _sample_factory.build_setup_by_matchup_id_result(normalized_matchup_id)
	if not bool(setup_result.get("ok", false)):
		return _propagate(setup_result, ErrorCodesScript.INVALID_BATTLE_SETUP, "PlayerBattleSession.start failed to build matchup %s" % normalized_matchup_id)
	var battle_setup = setup_result.get("data", null)
	if battle_setup == null:
		return _error(ErrorCodesScript.INVALID_BATTLE_SETUP, "PlayerBattleSession.start received empty battle_setup for %s" % normalized_matchup_id)
	var snapshot_paths_result: Dictionary = _sample_factory.content_snapshot_paths_for_setup_result(battle_setup)
	if not bool(snapshot_paths_result.get("ok", false)):
		return _propagate(snapshot_paths_result, ErrorCodesScript.INVALID_CONTENT_SNAPSHOT, "PlayerBattleSession.start failed to resolve snapshot paths")
	var resolved_seed: int = battle_seed if battle_seed != 0 else DEFAULT_BATTLE_SEED
	var create_result: Dictionary = _manager.create_session({
		"battle_seed": resolved_seed,
		"content_snapshot_paths": snapshot_paths_result.get("data", PackedStringArray()),
		"battle_setup": battle_setup,
	})
	if not bool(create_result.get("ok", false)):
		return create_result
	var create_payload: Dictionary = create_result.get("data", {})
	session_id = str(create_payload.get("session_id", "")).strip_edges()
	if session_id.is_empty():
		return _error(ErrorCodesScript.INVALID_SESSION, "PlayerBattleSession.start received empty session_id")
	current_snapshot_data = create_payload.get("public_snapshot", {})
	pending_p1_command = {}
	_legal_actions_by_side.clear()
	battle_finished = _resolve_battle_finished(current_snapshot_data)
	return ResultEnvelopeHelperScript.ok({
		"session_id": session_id,
		"public_snapshot": current_snapshot_data,
	})

func current_snapshot() -> Dictionary:
	return current_snapshot_data

func legal_actions(side_id: String) -> Variant:
	if _manager == null or session_id.is_empty():
		return _error(ErrorCodesScript.INVALID_SESSION, "PlayerBattleSession.legal_actions has no active session")
	var normalized_side_id := str(side_id).strip_edges()
	if normalized_side_id.is_empty():
		return _error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "PlayerBattleSession.legal_actions requires side_id")
	var legal_result: Dictionary = _manager.get_legal_actions(session_id, normalized_side_id)
	if not bool(legal_result.get("ok", false)):
		return legal_result
	_legal_actions_by_side[normalized_side_id] = legal_result.get("data", null)
	return legal_result

func submit_player_command(side_id: String, payload: Dictionary) -> Dictionary:
	if _manager == null or session_id.is_empty():
		return _error(ErrorCodesScript.INVALID_SESSION, "PlayerBattleSession.submit_player_command has no active session")
	var normalized_side_id := str(side_id).strip_edges()
	if normalized_side_id != PRIMARY_SIDE_ID:
		return _error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "PlayerBattleSession.submit_player_command only accepts primary side %s" % PRIMARY_SIDE_ID)
	if battle_finished:
		return _error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "PlayerBattleSession.submit_player_command battle already finished")
	if payload == null:
		return _error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "PlayerBattleSession.submit_player_command requires payload")
	var command_result: Dictionary = _manager.build_command(payload)
	if not bool(command_result.get("ok", false)):
		return command_result
	pending_p1_command = {
		"side_id": normalized_side_id,
		"command": command_result.get("data", null),
	}
	return ResultEnvelopeHelperScript.ok({
		"side_id": normalized_side_id,
		"has_pending_p1": true,
	})

func has_pending_p1() -> bool:
	return not pending_p1_command.is_empty() and pending_p1_command.get("command", null) != null

func run_turn() -> Dictionary:
	if _manager == null or session_id.is_empty():
		return _error(ErrorCodesScript.INVALID_SESSION, "PlayerBattleSession.run_turn has no active session")
	if battle_finished:
		return _error(ErrorCodesScript.INVALID_MANAGER_REQUEST, "PlayerBattleSession.run_turn battle already finished")
	if not has_pending_p1():
		return _error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "PlayerBattleSession.run_turn requires pending P1 command")
	var p2_command_result := _resolve_secondary_command()
	if not bool(p2_command_result.get("ok", false)):
		return p2_command_result
	var commands: Array = []
	commands.append(pending_p1_command.get("command", null))
	commands.append(p2_command_result.get("data", null))
	var run_result: Dictionary = _manager.run_turn(session_id, commands)
	if not bool(run_result.get("ok", false)):
		return run_result
	var run_payload: Dictionary = run_result.get("data", {})
	current_snapshot_data = run_payload.get("public_snapshot", {})
	pending_p1_command = {}
	_legal_actions_by_side.clear()
	battle_finished = _resolve_battle_finished(current_snapshot_data)
	return ResultEnvelopeHelperScript.ok({
		"public_snapshot": current_snapshot_data,
		"battle_finished": battle_finished,
	})

func close() -> void:
	if _closed:
		return
	_closed = true
	if _manager != null and not session_id.is_empty():
		_manager.close_session(session_id)
	session_id = ""
	pending_p1_command = {}
	_legal_actions_by_side.clear()
	current_snapshot_data = {}
	battle_finished = false
	if _owns_manager and _manager != null:
		_manager.dispose()
	_manager = null
	if _sample_factory != null:
		_sample_factory.dispose()
		_sample_factory = null
	_composer = null

func is_finished() -> bool:
	return battle_finished

func manager() -> Variant:
	return _manager

func current_side_to_select() -> String:
	# 返回当前需要玩家提交命令的 side_id；空串表示无需玩家操作（已结束 / 已提交 / 未启动）。
	if _closed or battle_finished or session_id.is_empty():
		return ""
	if has_pending_p1():
		return ""
	return PRIMARY_SIDE_ID

func legal_action_summary(side_id: String) -> Dictionary:
	# 把 LegalActionSet RefCounted 转成 Dict 形态，方便 UI 使用；envelope 风格。
	var legal_envelope: Variant = legal_actions(side_id)
	if not (legal_envelope is Dictionary):
		return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_SESSION, "PlayerBattleSession.legal_action_summary received non-dict envelope")
	var envelope: Dictionary = legal_envelope
	if not bool(envelope.get("ok", false)):
		return envelope
	var data: Variant = envelope.get("data", null)
	if data == null:
		return ResultEnvelopeHelperScript.error(ErrorCodesScript.INVALID_SESSION, "PlayerBattleSession.legal_action_summary missing legal action data")
	var summary := {
		"actor_public_id": str(_read_property(data, "actor_public_id", "")),
		"legal_skill_ids": _packed_to_string_array(_read_property(data, "legal_skill_ids", [])),
		"legal_switch_target_public_ids": _packed_to_string_array(_read_property(data, "legal_switch_target_public_ids", [])),
		"legal_ultimate_ids": _packed_to_string_array(_read_property(data, "legal_ultimate_ids", [])),
		"wait_allowed": bool(_read_property(data, "wait_allowed", false)),
		"forced_command_type": str(_read_property(data, "forced_command_type", "")).strip_edges(),
	}
	return ResultEnvelopeHelperScript.ok(summary)

func _packed_to_string_array(value) -> Array:
	var result: Array = []
	if value == null:
		return result
	if value is PackedStringArray:
		for entry in value:
			result.append(str(entry))
		return result
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result

func _compose_manager() -> String:
	_composer = BattleCoreComposerScript.new()
	if _composer == null:
		return "PlayerBattleSession failed to construct composer"
	var composed = _composer.compose_manager()
	if composed == null:
		var composer_error: Dictionary = _composer.error_state()
		return "PlayerBattleSession failed to compose manager: %s" % str(composer_error.get("message", "unknown composition error"))
	_manager = composed
	return ""

func _resolve_secondary_command() -> Dictionary:
	var legal_result: Dictionary = _manager.get_legal_actions(session_id, SECONDARY_SIDE_ID)
	if not bool(legal_result.get("ok", false)):
		return legal_result
	var legal_actions_value = legal_result.get("data", null)
	_legal_actions_by_side[SECONDARY_SIDE_ID] = legal_actions_value
	var policy_result: Dictionary = default_policy.decide(SECONDARY_SIDE_ID, current_snapshot_data, legal_actions_value)
	if not bool(policy_result.get("ok", false)):
		return policy_result
	var policy_payload: Dictionary = policy_result.get("data", {})
	if policy_payload == null:
		return _error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "PlayerBattleSession.run_turn default policy returned null payload")
	var actor_public_id := str(_read_property(legal_actions_value, "actor_public_id", "")).strip_edges()
	if actor_public_id.is_empty():
		return _error(ErrorCodesScript.INVALID_COMMAND_PAYLOAD, "PlayerBattleSession.run_turn missing actor_public_id for %s" % SECONDARY_SIDE_ID)
	var enriched_payload: Dictionary = policy_payload.duplicate(true)
	enriched_payload["side_id"] = SECONDARY_SIDE_ID
	enriched_payload["actor_public_id"] = actor_public_id
	enriched_payload["turn_index"] = int(current_snapshot_data.get("turn_index", 1))
	enriched_payload["command_source"] = str(enriched_payload.get("command_source", "policy"))
	var build_payload: Dictionary = _selection_adapter.build_player_payload(enriched_payload)
	var command_result: Dictionary = _manager.build_command(build_payload)
	if not bool(command_result.get("ok", false)):
		return command_result
	return ResultEnvelopeHelperScript.ok(command_result.get("data", null))

func _resolve_battle_finished(public_snapshot: Dictionary) -> bool:
	var battle_result = public_snapshot.get("battle_result", null)
	if battle_result is Dictionary:
		return bool(battle_result.get("finished", false))
	return false

func _read_property(value, property_name: String, default_value = null) -> Variant:
	if value == null:
		return default_value
	if value is Dictionary:
		return value.get(property_name, default_value)
	if typeof(value) != TYPE_OBJECT:
		return default_value
	for property_info in value.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return value.get(property_name)
	return default_value

func _error(error_code: String, error_message: String) -> Dictionary:
	return ResultEnvelopeHelperScript.error(error_code, error_message)

func _propagate(envelope: Dictionary, fallback_code: String, prefix: String) -> Dictionary:
	var error_code: Variant = envelope.get("error_code", fallback_code)
	if error_code == null:
		error_code = fallback_code
	var detail := str(envelope.get("error_message", ""))
	var combined := prefix
	if not detail.is_empty():
		combined = "%s: %s" % [prefix, detail]
	return ResultEnvelopeHelperScript.error(error_code, combined)
