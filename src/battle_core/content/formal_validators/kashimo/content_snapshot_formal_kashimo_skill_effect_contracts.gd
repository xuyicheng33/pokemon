extends RefCounted
class_name ContentSnapshotFormalKashimoSkillEffectContracts

const KashimoContractsScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_contracts.gd")
const KashimoChargeContractsScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_charge_contracts.gd")

var _contracts = KashimoContractsScript.new()
var _charge_contracts = KashimoChargeContractsScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate_core_skill_contract(validator, content_index, errors)
	_contracts.validate_kyokyo_contract(validator, content_index, errors)
	_charge_contracts.validate(validator, content_index, errors)
