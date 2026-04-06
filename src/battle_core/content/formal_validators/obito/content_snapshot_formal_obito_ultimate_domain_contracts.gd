extends RefCounted
class_name ContentSnapshotFormalObitoUltimateDomainContracts

const ObitoUltimateContractsScript := preload("res://src/battle_core/content/formal_validators/obito/content_snapshot_formal_obito_ultimate_contracts.gd")

var _contracts = ObitoUltimateContractsScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate(validator, content_index, errors)
