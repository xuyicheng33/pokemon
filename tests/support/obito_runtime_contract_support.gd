extends RefCounted
class_name ObitoRuntimeContractSupport

const HealBlockSupportScript := preload("res://tests/support/obito_runtime_contract_support_heal_block.gd")
const YinyangSupportScript := preload("res://tests/support/obito_runtime_contract_support_yinyang.gd")

var _heal_block_support = HealBlockSupportScript.new()
var _yinyang_support = YinyangSupportScript.new()

func run_qiudao_jiaotu_heal_block_contract(harness) -> Dictionary:
	return _heal_block_support.run_qiudao_jiaotu_heal_block_contract(harness)

func run_qiudao_jiaotu_heal_block_contract_for_matchup(
	harness,
	matchup_id: String,
	seed: int,
	p1_regular_skill_overrides: Dictionary = {},
	p2_regular_skill_overrides: Dictionary = {}
) -> Dictionary:
	return _heal_block_support.run_qiudao_jiaotu_heal_block_contract_for_matchup(
		harness,
		matchup_id,
		seed,
		p1_regular_skill_overrides,
		p2_regular_skill_overrides
	)

func run_qiudao_jiaotu_switch_persist_contract(harness) -> Dictionary:
	return _heal_block_support.run_qiudao_jiaotu_switch_persist_contract(harness)

func run_qiudao_jiaotu_switch_persist_contract_for_matchup(harness, matchup_id: String, seed: int) -> Dictionary:
	return _heal_block_support.run_qiudao_jiaotu_switch_persist_contract_for_matchup(harness, matchup_id, seed)

func run_qiudao_jiaotu_expire_sync_contract(harness) -> Dictionary:
	return _heal_block_support.run_qiudao_jiaotu_expire_sync_contract(harness)

func run_qiudao_jiaotu_expire_sync_contract_for_matchup(harness, matchup_id: String, seed: int) -> Dictionary:
	return _heal_block_support.run_qiudao_jiaotu_expire_sync_contract_for_matchup(harness, matchup_id, seed)

func run_yinyang_dun_non_skill_segment_ignored_contract(harness) -> Dictionary:
	return _yinyang_support.run_yinyang_dun_non_skill_segment_ignored_contract(harness)

func _build_non_skill_segment_chain_context(actor_id: String, target_unit_id: String):
	return _yinyang_support.build_non_skill_segment_chain_context(actor_id, target_unit_id)
