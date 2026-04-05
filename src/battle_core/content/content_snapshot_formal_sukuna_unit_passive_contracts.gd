extends RefCounted
class_name ContentSnapshotFormalSukunaUnitPassiveContracts

const SukunaContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_sukuna_contracts.gd")

var _contracts = SukunaContractsScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate_unit_contract(validator, content_index, errors)
	_contracts.validate_teach_love_contract(validator, content_index, errors)
