extends RefCounted
class_name ContentSnapshotFormalGojoUltimateDomainContracts

const ContractHelperScript := preload("res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_contract_helper.gd")
const FormalCharacterBaselinesScript := preload("res://src/shared/formal_character_baselines.gd")
const GojoDomainContractsScript := preload("res://src/battle_core/content/formal_validators/gojo/content_snapshot_formal_gojo_domain_contracts.gd")

var _helper = ContractHelperScript.new()
var _domain_contracts = GojoDomainContractsScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_helper.validate_skill_contracts(
		validator,
		content_index,
		errors,
		[FormalCharacterBaselinesScript.skill_contract("gojo", "gojo_unlimited_void")]
	)
	_domain_contracts.validate(validator, content_index, errors)
