extends "res://tests/support/gdunit_suite_bridge.gd"

## PlayerBattleSession 公开 API 契约：守住 start / current_snapshot /
## legal_actions / legal_action_summary / submit_player_command / run_turn /
## current_side_to_select 主路径与关键错误码。
##
## Batch G 加入 quick gate；防止 BattleScreen.gd 与 PlayerBattleSession 二者契约
## 再次出现 Batch D 那种"方法名/参数/envelope 形态"的全线漂移。

const PlayerBattleSessionScript := preload("res://src/adapters/player/player_battle_session.gd")
const PlayerDefaultPolicyScript := preload("res://src/adapters/player/player_default_policy.gd")
const LegalActionSetScript := preload("res://src/battle_core/contracts/legal_action_set.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

const DEFAULT_MATCHUP_ID := "gojo_vs_sample"
const DEFAULT_SEED := 9101

class CloseFailManager:
	extends RefCounted

	func close_session(_session_id: String) -> Dictionary:
		return {
			"ok": false,
			"data": null,
			"error_code": "test_close_failed",
			"error_message": "forced close failure",
		}


class LegalFailManager:
	extends RefCounted

	func get_legal_actions(_session_id: String, _side_id: String) -> Dictionary:
		return {
			"ok": false,
			"data": null,
			"error_code": "test_legal_actions_failed",
			"error_message": "forced legal action failure",
		}


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


func test_player_battle_session_rejects_duplicate_start_without_leaking_session() -> void:
	var session = PlayerBattleSessionScript.new()
	var first_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(first_envelope.get("ok", false)):
		fail("first PlayerBattleSession.start should succeed")
		session.close()
		return
	var first_session_id := String(session.session_id)
	var second_envelope: Dictionary = session.start("sukuna_setup", DEFAULT_SEED)
	if bool(second_envelope.get("ok", true)):
		fail("duplicate PlayerBattleSession.start should fail")
		session.close()
		return
	if String(second_envelope.get("error_code", "")) != ErrorCodesScript.INVALID_MANAGER_REQUEST:
		fail("duplicate start should map to INVALID_MANAGER_REQUEST, got %s" % String(second_envelope.get("error_code", "")))
		session.close()
		return
	if String(session.session_id) != first_session_id:
		fail("duplicate start must not overwrite active session_id")
		session.close()
		return
	var active_count_envelope: Dictionary = session.manager().active_session_count()
	if not bool(active_count_envelope.get("ok", false)) or int(active_count_envelope.get("data", {}).get("count", -1)) != 1:
		fail("duplicate start should leave exactly one active manager session")
		session.close()
		return
	var close_envelope: Dictionary = session.close()
	if not bool(close_envelope.get("ok", false)):
		fail("close after duplicate start should succeed")
		return


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


func test_player_battle_session_close_surfaces_manager_close_failure() -> void:
	var session = PlayerBattleSessionScript.new()
	session.set("_manager", CloseFailManager.new())
	session.session_id = "session_close_failure"
	var close_envelope: Dictionary = session.close()
	if bool(close_envelope.get("ok", true)):
		fail("PlayerBattleSession.close should return error when manager.close_session fails")
		return
	if String(close_envelope.get("error_code", "")) != "test_close_failed":
		fail("close failure should preserve manager error_code, got %s" % String(close_envelope.get("error_code", "")))
		return
	if session.session_id != "session_close_failure":
		fail("failed close should preserve session_id so caller can retry")
		return


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


func test_player_default_policy_selects_switch_when_only_switch_is_legal() -> void:
	var policy = PlayerDefaultPolicyScript.new()
	var legal_actions = LegalActionSetScript.new()
	legal_actions.actor_public_id = "P2-A"
	legal_actions.legal_switch_target_public_ids = PackedStringArray(["P2-B"])
	var result: Dictionary = policy.decide("P2", {}, legal_actions)
	if not bool(result.get("ok", false)):
		fail("PlayerDefaultPolicy should accept switch-only legal action set")
		return
	var data: Dictionary = result.get("data", {})
	if String(data.get("command_type", "")) != "switch":
		fail("PlayerDefaultPolicy should select switch command, got %s" % String(data.get("command_type", "")))
		return
	if String(data.get("target_public_id", "")) != "P2-B":
		fail("PlayerDefaultPolicy should select first switch target")
		return


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


func test_player_battle_session_run_turn_preserves_forced_command_query_failure() -> void:
	var session = PlayerBattleSessionScript.new(LegalFailManager.new())
	session.session_id = "session_legal_failure"
	session.current_snapshot_data = {
		"turn_index": 1,
		"battle_result": {"finished": false},
	}
	var envelope: Dictionary = session.run_turn()
	if bool(envelope.get("ok", true)):
		fail("run_turn should fail when forced command legal query fails")
		return
	if String(envelope.get("error_code", "")) != "test_legal_actions_failed":
		fail("run_turn should preserve legal query error_code, got %s" % String(envelope.get("error_code", "")))
		return
	if not String(envelope.get("error_message", "")).contains("forced legal action failure"):
		fail("run_turn should preserve legal query error_message, got %s" % String(envelope.get("error_message", "")))
		return


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


func test_player_battle_session_enriches_raw_player_commands_across_turns() -> void:
	var session = PlayerBattleSessionScript.new()
	var start_envelope: Dictionary = session.start(DEFAULT_MATCHUP_ID, DEFAULT_SEED)
	if not bool(start_envelope.get("ok", false)):
		fail("PlayerBattleSession.start should succeed for raw command enrichment")
		session.close()
		return
	for expected_turn in [1, 2]:
		var legal_envelope: Dictionary = session.legal_action_summary("P1")
		if not bool(legal_envelope.get("ok", false)):
			fail("legal_action_summary should succeed on turn %d" % expected_turn)
			session.close()
			return
		var legal_data: Dictionary = legal_envelope.get("data", {})
		var legal_skill_ids: Array = legal_data.get("legal_skill_ids", [])
		if legal_skill_ids.is_empty():
			fail("expected at least one legal skill on turn %d" % expected_turn)
			session.close()
			return
		var submit_envelope: Dictionary = session.submit_player_command("P1", {
			"command_type": "skill",
			"actor_public_id": String(legal_data.get("actor_public_id", "")),
			"skill_id": String(legal_skill_ids[0]),
		})
		if not bool(submit_envelope.get("ok", false)):
			fail("raw submit without turn_index should succeed on turn %d: %s" % [expected_turn, str(submit_envelope.get("error_message", ""))])
			session.close()
			return
		var run_envelope: Dictionary = session.run_turn()
		if not bool(run_envelope.get("ok", false)):
			fail("run_turn should accept enriched command on turn %d: %s" % [expected_turn, str(run_envelope.get("error_message", ""))])
			session.close()
			return
	var snapshot: Dictionary = session.current_snapshot()
	if int(snapshot.get("turn_index", 0)) < 3:
		fail("two raw UI-style commands should advance past turn 2, got turn_index=%d" % int(snapshot.get("turn_index", 0)))
		session.close()
		return
	session.close()
