extends SceneTree

const BattleCoreTestHarnessScript := preload("res://tests/support/battle_core_test_harness.gd")
const UltimateFieldTestHelperScript := preload("res://tests/support/ultimate_field_test_helper.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")

var _harness := BattleCoreTestHarnessScript.new()
var _helper := UltimateFieldTestHelperScript.new()

func _init() -> void:
	var case_name := str(OS.get_environment("CASE")).strip_edges().to_lower()
	if case_name.is_empty():
		case_name = "all"
	_run_cases(case_name)
	_harness.dispose_core_pool()
	quit()

func _run_cases(case_name: String) -> void:
	var cases := [
		"gojo_domain_success",
		"sukuna_domain_break",
		"tied_domain_clash",
		"normal_field_blocked_by_domain",
		"same_turn_dual_domain_clash",
	]
	for fixed_case in cases:
		if case_name != "all" and case_name != fixed_case:
			continue
		var result := _run_case(fixed_case)
		print("%s %s" % [fixed_case, JSON.stringify(result)])

func _run_case(case_name: String) -> Dictionary:
	match case_name:
		"gojo_domain_success":
			return _run_gojo_domain_success()
		"sukuna_domain_break":
			return _run_sukuna_domain_break()
		"tied_domain_clash":
			return _helper.run_tied_domain_clash(_harness, 4203)
		"normal_field_blocked_by_domain":
			return _run_normal_field_blocked_by_domain()
		"same_turn_dual_domain_clash":
			return _run_same_turn_dual_domain_clash()
		_:
			return {"error": "unknown case: %s" % case_name}

func _run_gojo_domain_success() -> Dictionary:
	var payload := _helper.build_gojo_vs_sample_state(_harness, 4201)
	if payload.has("error"):
		return payload
	var core = payload["core"]
	var content_index = payload["content_index"]
	var battle_state = payload["battle_state"]
	var gojo = battle_state.get_side("P1").get_active_unit()
	gojo.current_mp = gojo.max_mp
	gojo.ultimate_points = gojo.ultimate_points_cap
	core.battle_logger.reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 1, "P2", "P2-A")
	)
	return {
		"field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
		"gojo_sp_attack_stage": int(gojo.stat_stages.get("sp_attack", 0)),
		"log_size": core.battle_logger.event_log.size(),
	}

func _run_sukuna_domain_break() -> Dictionary:
	var payload := _helper.build_sukuna_vs_sample_state(_harness, 4202)
	if payload.has("error"):
		return payload
	var core = payload["core"]
	var content_index = payload["content_index"]
	var battle_state = payload["battle_state"]
	var sukuna = battle_state.get_side("P1").get_active_unit()
	sukuna.current_mp = sukuna.max_mp
	sukuna.ultimate_points = sukuna.ultimate_points_cap
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		core.command_builder.build_command({
			"turn_index": 1,
			"command_type": CommandTypesScript.ULTIMATE,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"skill_id": "sukuna_fukuma_mizushi",
		}),
		_helper.build_wait_command(core, 1, "P2", "P2-A"),
	])
	core.battle_logger.reset()
	core.turn_loop_controller.run_turn(battle_state, content_index, [
		core.command_builder.build_command({
			"turn_index": 2,
			"command_type": CommandTypesScript.SWITCH,
			"command_source": "manual",
			"side_id": "P1",
			"actor_public_id": "P1-A",
			"target_public_id": "P1-B",
		}),
		_helper.build_wait_command(core, 2, "P2", "P2-A"),
	])
	return {
		"field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
		"sukuna_attack_stage": int(sukuna.stat_stages.get("attack", 0)),
		"sukuna_sp_attack_stage": int(sukuna.stat_stages.get("sp_attack", 0)),
		"log_size": core.battle_logger.event_log.size(),
	}

func _run_normal_field_blocked_by_domain() -> Dictionary:
	var payload := _helper.build_gojo_vs_sample_state(_harness, 4204)
	if payload.has("error"):
		return payload
	var core = payload["core"]
	var content_index = payload["content_index"]
	var battle_state = payload["battle_state"]
	var gojo = battle_state.get_side("P1").get_active_unit()
	gojo.current_mp = gojo.max_mp
	gojo.ultimate_points = gojo.ultimate_points_cap
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_wait_command(core, 1, "P2", "P2-A")
	)
	core.battle_logger.reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_wait_command(core, 2, "P1", "P1-A"),
		_helper.build_skill_command(core, 2, "P2", "P2-A", "sample_field_call")
	)
	return {
		"field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
		"blocked_logged": _helper.has_domain_block_log(core.battle_logger.event_log, "sample_focus_field"),
		"log_size": core.battle_logger.event_log.size(),
	}

func _run_same_turn_dual_domain_clash() -> Dictionary:
	var payload := _helper.build_gojo_vs_sukuna_state(_harness, 4205)
	if payload.has("error"):
		return payload
	var core = payload["core"]
	var content_index = payload["content_index"]
	var battle_state = payload["battle_state"]
	var gojo = battle_state.get_side("P1").get_active_unit()
	var sukuna = battle_state.get_side("P2").get_active_unit()
	gojo.base_speed = 999
	gojo.current_mp = gojo.max_mp
	gojo.ultimate_points = gojo.ultimate_points_cap
	sukuna.current_mp = sukuna.max_mp
	sukuna.ultimate_points = sukuna.ultimate_points_cap
	core.battle_logger.reset()
	_helper.run_turn(
		core,
		battle_state,
		content_index,
		_helper.build_ultimate_command(core, 1, "P1", "P1-A", "gojo_unlimited_void"),
		_helper.build_ultimate_command(core, 1, "P2", "P2-A", "sukuna_fukuma_mizushi")
	)
	return {
		"field_id": battle_state.field_state.field_def_id if battle_state.field_state != null else null,
		"clash_logged": _helper.find_field_clash_event(core.battle_logger.event_log) != null,
		"sukuna_cancelled": _helper.has_action_cancelled_pre_start_on_actor(core.battle_logger.event_log, sukuna.unit_instance_id),
		"log_size": core.battle_logger.event_log.size(),
	}
