extends RefCounted
class_name ObitoRuntimeContractSupport

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()

func run_qiudao_jiaotu_heal_block_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var gojo_ritual_loadout := PackedStringArray(["gojo_ao", "gojo_aka", "gojo_reverse_ritual"])
	var battle_state = _support.build_battle_state(
		core,
		content_index,
		_support.build_obito_vs_gojo_setup(sample_factory, {}, {0: gojo_ritual_loadout}),
		1511
	)
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
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_vs_gojo_setup(sample_factory), 1512)
	var gojo = battle_state.get_side("P2").get_active_unit()
	if gojo == null:
		return harness.fail_result("missing gojo active unit for obito switch-persist contract")
	var mark_definition = content_index.effects.get("obito_qiudao_jiaotu_heal_block_mark", null)
	var rule_mod_effect = content_index.effects.get("obito_qiudao_jiaotu_heal_block_rule_mod", null)
	if mark_definition == null or rule_mod_effect == null:
		return harness.fail_result("missing heal block resources for obito switch-persist contract")
	var rule_mod_payload = rule_mod_effect.payloads[0]
	if core.service("effect_instance_service").create_instance(mark_definition, gojo.unit_instance_id, battle_state, "test_obito_heal_block", 2, 64) == null:
		return harness.fail_result("failed to seed obito heal block mark instance")
	if core.service("rule_mod_service").create_instance(
		rule_mod_payload,
		{"scope": "unit", "id": gojo.unit_instance_id},
		battle_state,
		"test_obito_heal_block",
		2,
		64
	) == null:
		return harness.fail_result("failed to seed obito heal block rule mod instance")
	core.service("turn_loop_controller").run_turn(battle_state, content_index, [
		_support.build_manual_wait_command(core, 1, "P1", "P1-A"),
		_support.build_manual_switch_command(core, 1, "P2", "P2-A", "P2-B"),
	])
	var benched_gojo = _support.find_unit_on_side(battle_state, "P2", "gojo_satoru")
	if benched_gojo == null:
		return harness.fail_result("failed to find benched gojo after switch")
	if _support.count_effect_instances(benched_gojo, "obito_qiudao_jiaotu_heal_block_mark") != 1:
		return harness.fail_result("heal block mark should persist on switch while duration remains")
	var persisted_rule_mod = _support.find_rule_mod_instance(benched_gojo, "incoming_heal_final_mod")
	if persisted_rule_mod == null:
		return harness.fail_result("incoming_heal_final_mod should persist on switch with the target")
	if int(persisted_rule_mod.remaining) != 1:
		return harness.fail_result("persisted heal block rule mod should tick down to remaining=1 after turn_end")
	return harness.pass_result()

func run_qiudao_jiaotu_expire_sync_contract(harness) -> Dictionary:
	var core_payload = harness.build_core()
	if core_payload.has("error"):
		return harness.fail_result(str(core_payload["error"]))
	var core = core_payload["core"]
	var sample_factory = harness.build_sample_factory()
	if sample_factory == null:
		return harness.fail_result("SampleBattleFactory init failed")
	var content_index = harness.build_loaded_content_index(sample_factory)
	var battle_state = _support.build_battle_state(core, content_index, _support.build_obito_vs_gojo_setup(sample_factory), 1513)
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
