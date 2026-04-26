extends "res://tests/support/gdunit_suite_bridge.gd"

const GojoTestSupportScript := preload("res://tests/support/gojo_test_support.gd")

var _support = GojoTestSupportScript.new()


func test_gojo_mugen_incoming_accuracy_contract() -> void:
	var state_payload = _support.build_sample_vs_gojo_state(_harness, 1210, true)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var attacker = battle_state.get_side("P1").get_active_unit()
	var gojo_unit = battle_state.get_side("P2").get_active_unit()
	if _support.count_rule_mod_instances(gojo_unit, "incoming_accuracy") != 1:
		fail("gojo active unit should carry one incoming_accuracy rule_mod from 无下限")
		return
	var accuracy_skill = _support.build_accuracy_skill("test_gojo_mugen_95", 95)
	var command = _support.build_resolved_skill_command(core, 1, "P1", attacker.public_id, attacker.unit_instance_id, accuracy_skill.id)
	var reduced_hit = core.service("action_cast_service").resolve_hit(command, accuracy_skill, gojo_unit, battle_state, content_index)
	if abs(float(reduced_hit.get("hit_rate", -1.0)) - 0.85) > 0.0001:
		fail("无下限应把 95 命中的敌方来袭技能压到 85")
		return
	accuracy_skill.accuracy = 100
	var guaranteed_hit = core.service("action_cast_service").resolve_hit(command, accuracy_skill, gojo_unit, battle_state, content_index)
	if guaranteed_hit.get("hit_roll", "not-null") != null or abs(float(guaranteed_hit.get("hit_rate", -1.0)) - 1.0) > 0.0001:
		fail("无下限不应影响 100 命中的必中动作")
		return
	_support.set_field_state(battle_state, "sukuna_malevolent_shrine_field", attacker.unit_instance_id)
	accuracy_skill.accuracy = 90
	var field_override_hit = core.service("action_cast_service").resolve_hit(command, accuracy_skill, gojo_unit, battle_state, content_index)
	if field_override_hit.get("hit_roll", "not-null") != null or abs(float(field_override_hit.get("hit_rate", -1.0)) - 1.0) > 0.0001:
		fail("无下限不应影响领域 creator_accuracy_override 带来的必中")
		return

func test_gojo_mugen_reentry_contract() -> void:
	var state_payload = _support.build_sample_vs_gojo_state(_harness, 1211, false)
	if state_payload.has("error"):
		fail(str(state_payload["error"]))
		return
	var core = state_payload["core"]
	var content_index = state_payload["content_index"]
	var battle_state = state_payload["battle_state"]
	var gojo_unit = battle_state.get_side("P2").get_active_unit()
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_wait_command(core, 1, "P1", "P1-A"),
		_support.build_switch_command(core, 1, "P2", "P2-A", "P2-B"),
	])
	if gojo_unit.leave_state == "active" or _support.count_rule_mod_instances(gojo_unit, "incoming_accuracy") != 0:
		fail("gojo 离场后应清掉当前入场时挂上的 incoming_accuracy rule_mod")
		return
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_wait_command(core, 2, "P1", "P1-A"),
		_support.build_switch_command(core, 2, "P2", "P2-B", "P2-A"),
	])
	var reentered_gojo = battle_state.get_side("P2").get_active_unit()
	if reentered_gojo == null or reentered_gojo.definition_id != "gojo_satoru":
		fail("gojo should return to active slot after switching back in")
		return
	if _support.count_rule_mod_instances(reentered_gojo, "incoming_accuracy") != 1:
		fail("gojo 再入场后应重新挂上 incoming_accuracy rule_mod")
		return
	var attacker = battle_state.get_side("P1").get_active_unit()
	var accuracy_skill = _support.build_accuracy_skill("test_gojo_mugen_reentry_95", 95)
	var command = _support.build_resolved_skill_command(core, 2, "P1", attacker.public_id, attacker.unit_instance_id, accuracy_skill.id)
	var hit_info = core.service("action_cast_service").resolve_hit(command, accuracy_skill, reentered_gojo, battle_state, content_index)
	if abs(float(hit_info.get("hit_rate", -1.0)) - 0.85) > 0.0001:
		fail("gojo 再入场后无下限仍应把来袭 95 命中压到 85")
		return

