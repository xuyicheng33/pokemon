extends SceneTree

## Player MVP headless smoke runner.
##
## 用 PlayerBattleSession + PlayerDefaultPolicy 双侧 policy 推进到 battle_result.finished，
## 与 manual_battle_full_run.gd 形态对齐。从 OS env 读 MATCHUP_ID / BATTLE_SEED；
## 失败时 push_error("BATTLE_PLAYER_FAILED:") + quit(1)，成功打印 player_summary JSON 后 quit(0)。

const PlayerBattleSessionScript := preload("res://src/adapters/player/player_battle_session.gd")
const PlayerDefaultPolicyScript := preload("res://src/adapters/player/player_default_policy.gd")
const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")

const DEFAULT_MATCHUP_ID := "gojo_vs_sample"
const DEFAULT_BATTLE_SEED := 9101
const MAX_TURNS := 64
const PRIMARY_SIDE_ID := "P1"
const FAIL_PREFIX := "BATTLE_PLAYER_FAILED:"

func _init() -> void:
	var matchup_id := str(OS.get_environment("MATCHUP_ID")).strip_edges()
	if matchup_id == "":
		matchup_id = DEFAULT_MATCHUP_ID
	var raw_seed := str(OS.get_environment("BATTLE_SEED")).strip_edges()
	var battle_seed: int = DEFAULT_BATTLE_SEED
	if raw_seed != "":
		battle_seed = int(raw_seed)

	var session = PlayerBattleSessionScript.new()
	var policy = PlayerDefaultPolicyScript.new()
	var selection_adapter = PlayerSelectionAdapterScript.new()

	var start_envelope: Dictionary = session.start(matchup_id, battle_seed)
	if not bool(start_envelope.get("ok", false)):
		_fail("start_envelope_not_ok", start_envelope)
		return

	var turn_index: int = 0
	var command_steps: int = 0
	var public_snapshot: Dictionary = session.current_snapshot()
	while not session.is_finished() and turn_index < MAX_TURNS:
		# 从 P1 角度走 PlayerDefaultPolicy 决策一条命令；后台还会再让 session 内部走 P2 策略。
		var legal_envelope: Variant = session.legal_actions(PRIMARY_SIDE_ID)
		if not (legal_envelope is Dictionary) or not bool(legal_envelope.get("ok", false)):
			_fail("legal_actions_not_ok", legal_envelope)
			return
		var legal_actions = legal_envelope.get("data", null)
		var policy_result: Dictionary = policy.decide(PRIMARY_SIDE_ID, public_snapshot, legal_actions)
		if not bool(policy_result.get("ok", false)):
			_fail("policy_decide_failed", policy_result)
			return
		var policy_payload: Dictionary = policy_result.get("data", {})
		var actor_public_id := str(_read_property(legal_actions, "actor_public_id", "")).strip_edges()
		if actor_public_id == "":
			_fail("missing_actor_public_id", legal_envelope)
			return
		var enriched_payload: Dictionary = policy_payload.duplicate(true)
		enriched_payload["side_id"] = PRIMARY_SIDE_ID
		enriched_payload["actor_public_id"] = actor_public_id
		enriched_payload["turn_index"] = int(public_snapshot.get("turn_index", 1))
		enriched_payload["command_source"] = str(enriched_payload.get("command_source", "policy"))
		var build_payload: Dictionary = selection_adapter.build_player_payload(enriched_payload)
		var submit_envelope: Dictionary = session.submit_player_command(PRIMARY_SIDE_ID, build_payload)
		if not bool(submit_envelope.get("ok", false)):
			_fail("submit_player_command_failed", submit_envelope)
			return
		var run_envelope: Dictionary = session.run_turn()
		if not bool(run_envelope.get("ok", false)):
			_fail("run_turn_failed", run_envelope)
			return
		public_snapshot = session.current_snapshot()
		turn_index = int(public_snapshot.get("turn_index", turn_index + 1))
		command_steps += 1

	if not session.is_finished():
		_fail("turn_limit_reached", {"turn_index": turn_index})
		return

	var battle_result: Dictionary = {}
	if public_snapshot.get("battle_result", null) is Dictionary:
		battle_result = public_snapshot["battle_result"]
	var event_log_cursor: int = 0
	if session.manager() != null and session.session_id != "":
		var event_envelope: Dictionary = session.manager().get_event_log_snapshot(session.session_id, 0)
		if bool(event_envelope.get("ok", false)) and event_envelope.get("data", null) is Dictionary:
			event_log_cursor = int(event_envelope.get("data", {}).get("total_size", 0))

	var summary := {
		"matchup_id": matchup_id,
		"battle_seed": battle_seed,
		"p1_control_mode": "policy",
		"p2_control_mode": "policy",
		"winner_side_id": battle_result.get("winner_side_id", ""),
		"reason": str(battle_result.get("reason", "")),
		"result_type": str(battle_result.get("result_type", "")),
		"turn_index": turn_index,
		"event_log_cursor": event_log_cursor,
		"command_steps": command_steps,
	}
	session.close()
	print(JSON.stringify(summary))
	quit(0)

func _fail(label: String, payload: Variant) -> void:
	push_error("%s %s payload=%s" % [FAIL_PREFIX, label, str(payload)])
	quit(1)

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
