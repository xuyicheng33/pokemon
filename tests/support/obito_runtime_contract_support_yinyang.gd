extends RefCounted
class_name ObitoRuntimeContractSupportYinyang

const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ObitoTestSupportScript := preload("res://tests/support/obito_test_support.gd")

var _support = ObitoTestSupportScript.new()

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
	battle_state.set_phase_chain_context(build_non_skill_segment_chain_context(target.unit_instance_id, obito.unit_instance_id))
	var invalid_code = core.service("trigger_batch_runner").execute_trigger_batch(
		"on_receive_action_damage_segment",
		battle_state,
		content_index,
		[obito.unit_instance_id],
		battle_state.current_chain_context()
	)
	if invalid_code != null:
		return harness.fail_result("non-skill segment trigger probe should not invalidate battle: %s" % str(invalid_code))
	if _support.count_effect_instances(obito, "obito_yinyang_zhili") != baseline_count:
		return harness.fail_result("obito_yinyang_dun should ignore non-skill damage segment triggers")
	return harness.pass_result()

func build_non_skill_segment_chain_context(actor_id: String, target_unit_id: String):
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
