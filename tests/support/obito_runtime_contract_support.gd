extends RefCounted
class_name ObitoRuntimeContractSupport

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()

func run_qiudao_jiaotu_heal_block_contract(harness) -> Dictionary:
	return run_qiudao_jiaotu_heal_block_contract_for_matchup(
		harness,
		"obito_vs_gojo",
		1511,
		{},
		{0: PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])}
	)

func run_qiudao_jiaotu_heal_block_contract_for_matchup(
	harness,
	matchup_id: String,
	seed: int,
	p1_regular_skill_overrides: Dictionary = {},
	p2_regular_skill_overrides: Dictionary = {}
) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var battle_setup_result: Dictionary = _support.build_matchup_setup_result(sample_factory, matchup_id, {
		"P1": p1_regular_skill_overrides,
		"P2": p2_regular_skill_overrides,
	})
	if not bool(battle_setup_result.get("ok", false)):
		return harness.fail_result("failed to build obito heal block setup: %s" % String(battle_setup_result.get("error_message", "unknown error")))
	var battle_setup = battle_setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, seed)
	var obito = battle_state.get_side("P1").get_active_unit()
	var gojo = battle_state.get_side("P2").get_active_unit()
	if obito == null or gojo == null:
		return harness.fail_result("missing active units for obito heal block contract")
	gojo.current_hp = max(1, gojo.max_hp - 30)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_qiudao_jiaotu"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	if _support.count_effect_instances(gojo, "obito_qiudao_jiaotu_heal_block_mark") != 1:
		return harness.fail_result("obito_qiudao_jiaotu should apply public heal block mark to target")
	if _support.count_rule_mod_instances(gojo, "incoming_heal_final_mod") != 1:
		return harness.fail_result("obito_qiudao_jiaotu should apply incoming_heal_final_mod to target")
	var before_hp := int(gojo.current_hp)
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 2, "P1", "P1-A"),
		_support.build_manual_skill_command(core, 2, "P2", "P2-A", "gojo_reverse_ritual"),
	])
	if int(gojo.current_hp) != before_hp:
		return harness.fail_result("incoming_heal_final_mod should fully block gojo reverse heal while mark is active")
	if _support.collect_target_heal_events(core.service("battle_logger").event_log, gojo.unit_instance_id).size() != 0:
		return harness.fail_result("blocked reverse heal should not emit effect:heal event")
	return harness.pass_result()

func run_qiudao_jiaotu_switch_persist_contract(harness) -> Dictionary:
	return run_qiudao_jiaotu_switch_persist_contract_for_matchup(harness, "obito_vs_gojo", 1512)

func run_qiudao_jiaotu_switch_persist_contract_for_matchup(harness, matchup_id: String, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var battle_setup_result: Dictionary = _support.build_matchup_setup_result(sample_factory, matchup_id)
	if not bool(battle_setup_result.get("ok", false)):
		return harness.fail_result("failed to build obito switch-persist setup: %s" % String(battle_setup_result.get("error_message", "unknown error")))
	var battle_setup = battle_setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, seed)
	var gojo = battle_state.get_side("P2").get_active_unit()
	if battle_state.get_side("P1").get_active_unit() == null or gojo == null:
		return harness.fail_result("missing active units for obito switch-persist contract")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_qiudao_jiaotu"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	if _support.count_effect_instances(gojo, "obito_qiudao_jiaotu_heal_block_mark") != 1:
		return harness.fail_result("turn 1 should seed heal block mark before testing switch persistence")
	if _support.count_rule_mod_instances(gojo, "incoming_heal_final_mod") != 1:
		return harness.fail_result("turn 1 should seed incoming_heal_final_mod before testing switch persistence")
	var switch_command = _support.build_manual_switch_command(core, 2, "P2", "P2-A", "P2-B")
	var resolve_result: Dictionary = core.service("turn_resolution_service").resolve_commands_for_turn(
		battle_state,
		content_index,
		[switch_command]
	)
	if resolve_result.get("invalid_code", null) != null:
		return harness.fail_result("failed to resolve switch command for obito switch-persist contract")
	var action_queue = core.service("action_queue_builder").build_queue(
		resolve_result.get("locked_commands", []),
		battle_state,
		content_index
	)
	if core.service("action_queue_builder").invalid_battle_code() != null:
		return harness.fail_result("failed to build switch queue for obito switch-persist contract")
	var switch_action = null
	for queued_action in action_queue:
		if queued_action != null and queued_action.command != null and String(queued_action.command.command_type) == "switch":
			switch_action = queued_action
			break
	if switch_action == null:
		return harness.fail_result("switch-persist contract should include one resolved switch action in the queued turn")
	var action_result = core.service("action_executor").execute_action(switch_action, battle_state, content_index)
	if action_result == null or String(action_result.result_type) != "resolved":
		return harness.fail_result("manual switch action should resolve before turn_end during switch-persist contract")
	if action_result.invalid_battle_code != null:
		return harness.fail_result("manual switch action should stay valid: %s" % str(action_result.invalid_battle_code))
	var benched_gojo = _support.find_unit_on_side(battle_state, "P2", "gojo_satoru")
	if benched_gojo == null:
		return harness.fail_result("failed to find benched gojo after switch")
	if _support.count_effect_instances(benched_gojo, "obito_qiudao_jiaotu_heal_block_mark") != 1:
		return harness.fail_result("heal block mark should persist on switch while duration remains")
	var persisted_rule_mod = _support.find_rule_mod_instance(benched_gojo, "incoming_heal_final_mod")
	if persisted_rule_mod == null:
		return harness.fail_result("incoming_heal_final_mod should persist on switch with the target")
	if int(persisted_rule_mod.remaining) != 1:
		return harness.fail_result("persisted heal block rule mod should keep remaining=1 before the next turn_end")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 2, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-B"),
	])
	if _support.count_effect_instances(benched_gojo, "obito_qiudao_jiaotu_heal_block_mark") != 0:
		return harness.fail_result("heal block mark should expire on the benched target at the next shared turn_end window")
	if _support.count_rule_mod_instances(benched_gojo, "incoming_heal_final_mod") != 0:
		return harness.fail_result("incoming_heal_final_mod should expire on the benched target at the next shared turn_end window")
	return harness.pass_result()

func run_qiudao_jiaotu_expire_sync_contract(harness) -> Dictionary:
	return run_qiudao_jiaotu_expire_sync_contract_for_matchup(harness, "obito_vs_gojo", 1513)

func run_qiudao_jiaotu_expire_sync_contract_for_matchup(harness, matchup_id: String, seed: int) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var battle_setup_result: Dictionary = _support.build_matchup_setup_result(sample_factory, matchup_id)
	if not bool(battle_setup_result.get("ok", false)):
		return harness.fail_result("failed to build obito expire-sync setup: %s" % String(battle_setup_result.get("error_message", "unknown error")))
	var battle_setup = battle_setup_result.get("data", null)
	var content_index = harness.build_loaded_content_index_for_setup(sample_factory, battle_setup)
	var battle_state = _support.build_battle_state(core, content_index, battle_setup, seed)
	var gojo = battle_state.get_side("P2").get_active_unit()
	if gojo == null:
		return harness.fail_result("missing gojo active unit for obito expire sync contract")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_qiudao_jiaotu"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 2, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 2, "P2", "P2-A"),
	])
	core.service("battle_logger").reset()
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 3, "P1", "P1-A"),
		_support.build_manual_wait_command(core, 3, "P2", "P2-A"),
	])
	if _support.count_effect_instances(gojo, "obito_qiudao_jiaotu_heal_block_mark") != 0:
		return harness.fail_result("heal block public mark should expire on the shared turn_end window")
	if _support.count_rule_mod_instances(gojo, "incoming_heal_final_mod") != 0:
		return harness.fail_result("incoming_heal_final_mod should expire on the same turn_end window as the public mark")
	return harness.pass_result()

func run_yinyang_dun_non_skill_segment_ignored_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_setup(sample_factory), 1524)
	var obito = battle_state.get_side("P1").get_active_unit()
	var target = battle_state.get_side("P2").get_active_unit()
	if obito == null or target == null:
		return harness.fail_result("missing active units for obito non-skill segment contract")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_skill_command(core, 1, "P1", "P1-A", "obito_yinyang_dun"),
		_support.build_manual_wait_command(core, 1, "P2", "P2-A"),
	])
	var baseline_count := _support.count_effect_instances(obito, "obito_yinyang_zhili")
	if baseline_count != 1:
		return harness.fail_result("obito_yinyang_dun should seed exactly one initial stack before non-skill trigger probe")
	battle_state.chain_context = _build_non_skill_segment_chain_context(target.unit_instance_id, obito.unit_instance_id)
	var invalid_code = core.service("trigger_batch_runner").execute_trigger_batch(
		"on_receive_action_damage_segment",
		battle_state,
		content_index,
		[obito.unit_instance_id],
		battle_state.chain_context
	)
	if invalid_code != null:
		return harness.fail_result("non-skill segment trigger probe should not invalidate battle: %s" % str(invalid_code))
	if _support.count_effect_instances(obito, "obito_yinyang_zhili") != baseline_count:
		return harness.fail_result("obito_yinyang_dun should ignore non-skill damage segment triggers")
	return harness.pass_result()

func _build_non_skill_segment_chain_context(actor_id: String, target_unit_id: String):
	var chain_context = ChainContextScript.new()
	chain_context.event_chain_id = "test_obito_non_skill_segment"
	chain_context.chain_origin = "action"
	chain_context.command_type = "switch"
	chain_context.command_source = "manual"
	chain_context.actor_id = actor_id
	chain_context.action_actor_id = actor_id
	chain_context.target_unit_id = target_unit_id
	chain_context.action_combat_type_id = "fire"
	chain_context.action_segment_index = 1
	chain_context.action_segment_total = 1
	return chain_context
