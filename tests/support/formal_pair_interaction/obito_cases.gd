extends RefCounted
class_name FormalPairInteractionObitoCases

const FormalCharacterTestSupportScript := preload("res://tests/support/formal_character_test_support.gd")
const SukunaTestSupportScript := preload("res://tests/support/sukuna_test_support.gd")

var _formal_support = FormalCharacterTestSupportScript.new()
var _sukuna_support = SukunaTestSupportScript.new()

func run_sukuna_vs_obito_field_seal_and_kamado_lifecycle(harness, case_spec: Dictionary) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var setup_result: Dictionary = sample_factory.build_setup_by_matchup_id_result(String(case_spec.get("matchup_id", "")))
	if not bool(setup_result.get("ok", false)):
		return harness.fail_result("failed to build sukuna vs obito interaction setup: %s" % String(setup_result.get("error_message", "unknown error")))
	var battle_setup = setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = harness.build_initialized_battle(core, content_index, sample_factory, int(case_spec.get("battle_seed", 0)), battle_setup)
	var sukuna = battle_state.get_side("P1").get_active_unit()
	var obito = battle_state.get_side("P2").get_active_unit()
	if sukuna == null or obito == null:
		return harness.fail_result("missing active units for sukuna vs obito interaction")
	sukuna.current_mp = sukuna.max_mp
	sukuna.ultimate_points = sukuna.ultimate_points_cap
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_formal_support.build_manual_ultimate_command(core, 1, "P1", "P1-A", "sukuna_fukuma_mizushi"),
		_formal_support.build_manual_skill_command(core, 1, "P2", "P2-A", "obito_qiudao_jiaotu"),
	])
	if _formal_support.count_rule_mod_instances(sukuna, "incoming_heal_final_mod") != 1:
		return harness.fail_result("obito heal block should coexist on sukuna while malevolent shrine is active")
	if battle_state.field_state == null or String(battle_state.field_state.field_def_id) != "sukuna_malevolent_shrine_field":
		return harness.fail_result("malevolent shrine should remain active after the cross-role opening turn")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_formal_support.build_manual_skill_command(core, 2, "P1", "P1-A", "sukuna_hiraku"),
		_formal_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	if _formal_support.count_effect_instances(obito, "sukuna_kamado_mark") != 1:
		return harness.fail_result("sukuna hiraku should successfully seed exactly one kamado stack before the switch/expire chain")
	var hp_before_switch := int(obito.current_hp)
	var replacement_preview = battle_state.get_side("P2").find_unit(String(battle_state.get_side("P2").bench_order[0])) if battle_state.get_side("P2").bench_order.size() > 0 else null
	var replacement_hp_before := int(replacement_preview.current_hp) if replacement_preview != null else -1
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_formal_support.build_manual_wait_command(core, 3, "P1", "P1-A"),
		_formal_support.build_manual_switch_command(core, 3, "P2", "P2-A", "P2-B"),
	])
	if int(obito.current_hp) >= hp_before_switch:
		return harness.fail_result("kamado on_exit burst should damage obito before the replacement finishes entering")
	var replacement = battle_state.get_side("P2").get_active_unit()
	if replacement == null or String(replacement.public_id) != "P2-B":
		return harness.fail_result("obito side should finish the switch/expire chain on the replacement unit")
	if battle_state.field_state != null:
		return harness.fail_result("malevolent shrine should naturally expire on the same turn the marked target switches out")
	var expected_expire_damage := _sukuna_support.calc_expected_fixed_effect_damage(core, content_index, "sukuna_domain_expire_burst", replacement)
	if replacement_hp_before - int(replacement.current_hp) != expected_expire_damage:
		return harness.fail_result("malevolent shrine natural expire burst should still land on the replacement target after the switch chain")
	if _formal_support.count_rule_mod_instances(sukuna, "incoming_heal_final_mod") != 0:
		return harness.fail_result("obito heal block should expire cleanly and not leak past the mixed domain lifecycle")
	return harness.pass_result()
