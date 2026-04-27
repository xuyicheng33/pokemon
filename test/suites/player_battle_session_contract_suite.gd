extends "res://tests/support/gdunit_suite_bridge.gd"

## PlayerBattleSession 公开 API 契约：守住 start / current_snapshot /
## legal_actions / legal_action_summary / submit_player_command / run_turn /
## current_side_to_select 主路径与关键错误码。
##
## Batch G 加入 quick gate；防止 BattleScreen.gd 与 PlayerBattleSession 二者契约
## 再次出现 Batch D 那种"方法名/参数/envelope 形态"的全线漂移。

const PlayerBattleSessionScript := preload("res://src/adapters/player/player_battle_session.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

const DEFAULT_MATCHUP_ID := "gojo_vs_sample"
const DEFAULT_SEED := 9101


func test_player_battle_session_start_returns_session_id_and_snapshot() -> void:
	var session = PlayerBattleSessionScript.new()
	var envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed: %s" % str(envelope.get("error_message", "")))
		session.close()
		return
	var data: Dictionary = envelope.get("data", {})
	if String(data.get("session_id", "")).strip_edges().is_empty():
		fail("PlayerBattleSession.start envelope.data should expose session_id")
		session.close()
		return
	if not (data.get("public_snapshot", null) is Dictionary):
		fail("PlayerBattleSession.start envelope.data should expose public_snapshot")
		session.close()
		return
	session.close()


func test_player_battle_session_start_with_empty_matchup_returns_invalid_request() -> void:
	var session = PlayerBattleSessionScript.new()
	var envelope: Dictionary = session.start("", DEFAULT_SEED)
	if bool(envelope.get("ok", true)):
		fail("PlayerBattleSession.start should reject empty matchup_id")
		session.close()
		return
	if String(envelope.get("error_code", "")) != ErrorCodesScript.INVALID_MANAGER_REQUEST:
		fail("empty matchup_id should map to INVALID_MANAGER_REQUEST, got %s" % String(envelope.get("error_code", "")))
		session.close()
		return
	session.close()


func test_player_battle_session_current_snapshot_has_p1_p2_sides() -> void:
	var session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(start_envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed for snapshot contract")
		session.close()
		return
	var snapshot: Dictionary = session.current_snapshot()
	var sides = snapshot.get("sides", null)
	if not (sides is Array):
		fail("public_snapshot.sides should be Array")
		session.close()
		return
	var side_ids: Array = []
	for raw_side in sides:
		if raw_side is Dictionary:
			side_ids.append(String(raw_side.get("side_id", "")))
	if not (side_ids.has("P1") and side_ids.has("P2")):
		fail("public_snapshot.sides should contain both P1 and P2, got %s" % str(side_ids))
		session.close()
		return
	session.close()


func test_player_battle_session_legal_actions_returns_envelope_with_legal_action_set() -> void:
	var session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(start_envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed for legal_actions contract")
		session.close()
		return
	var envelope = session.legal_actions("P1")
	if not (envelope is Dictionary) or not bool(envelope.get("ok", false)):
		fail("PlayerBattleSession.legal_actions(P1) should return ok envelope")
		session.close()
		return
	var data = envelope.get("data", null)
	# data 应该是 LegalActionSet（RefCounted），暴露 actor_public_id 等属性
	if data == null:
		fail("legal_actions envelope.data should not be null")
		session.close()
		return
	if typeof(data) != TYPE_OBJECT:
		fail("legal_actions envelope.data should be RefCounted, got typeof=%d" % typeof(data))
		session.close()
		return
	# 走属性读：LegalActionSet RefCounted
	var actor_public_id: String = String(data.actor_public_id) if data.has_method("get") else ""
	# get 通过反射拿不到 actor_public_id 时退到直接属性访问（GDScript 严格模式下 RefCounted 字段可直接读）
	if actor_public_id == "":
		actor_public_id = String(data.actor_public_id)
	if actor_public_id.is_empty():
		fail("legal_actions envelope.data.actor_public_id should not be empty")
		session.close()
		return
	session.close()


func test_player_battle_session_legal_action_summary_dict_shape() -> void:
	var session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(start_envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed for legal_action_summary contract")
		session.close()
		return
	var envelope: Dictionary = session.legal_action_summary("P1")
	if not bool(envelope.get("ok", false)):
		fail("legal_action_summary(P1) should be ok")
		session.close()
		return
	var data: Dictionary = envelope.get("data", {})
	for key in ["actor_public_id", "legal_skill_ids", "legal_switch_target_public_ids", "legal_ultimate_ids", "wait_allowed", "forced_command_type"]:
		if not data.has(key):
			fail("legal_action_summary data missing key: %s" % key)
			session.close()
			return
	if not (data["legal_skill_ids"] is Array):
		fail("legal_action_summary.legal_skill_ids should be Array")
		session.close()
		return
	session.close()


func test_player_battle_session_submit_player_command_with_p2_returns_invalid_request() -> void:
	var session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(start_envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed for submit contract")
		session.close()
		return
	var envelope: Dictionary = session.submit_player_command("P2", {"command_type": "wait", "side_id": "P2", "actor_public_id": "x"})
	if bool(envelope.get("ok", true)):
		fail("submit_player_command should reject non-P1 side")
		session.close()
		return
	if String(envelope.get("error_code", "")) != ErrorCodesScript.INVALID_MANAGER_REQUEST:
		fail("submit P2 should map to INVALID_MANAGER_REQUEST, got %s" % String(envelope.get("error_code", "")))
		session.close()
		return
	session.close()


func test_player_battle_session_run_turn_without_pending_command_fails() -> void:
	var session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(start_envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed for run_turn contract")
		session.close()
		return
	var envelope: Dictionary = session.run_turn()
	if bool(envelope.get("ok", true)):
		fail("run_turn without pending P1 command should fail")
		session.close()
		return
	if String(envelope.get("error_code", "")) != ErrorCodesScript.INVALID_COMMAND_PAYLOAD:
		fail("run_turn should map to INVALID_COMMAND_PAYLOAD when pending P1 missing, got %s" % String(envelope.get("error_code", "")))
		session.close()
		return
	session.close()


func test_player_battle_session_current_side_to_select_returns_p1_after_start() -> void:
	var session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(start_envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed for current_side_to_select contract")
		session.close()
		return
	if session.current_side_to_select() != "P1":
		fail("current_side_to_select after fresh start should be P1, got %s" % session.current_side_to_select())
		session.close()
		return
	if session.is_finished():
		fail("session should not be finished immediately after start")
		session.close()
		return
	session.close()
