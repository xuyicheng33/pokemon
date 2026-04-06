extends RefCounted
class_name ContentSnapshotFormalKashimoUnitPassiveContracts

const KashimoContractsScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_contracts.gd")
const KashimoPassiveContractsScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_passive_contracts.gd")

var _contracts = KashimoContractsScript.new()
var _passive_contracts = KashimoPassiveContractsScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate_unit_contract(validator, content_index, errors)
	_passive_contracts.validate_charge_separation_contract(validator, content_index, errors)
	_passive_contracts.validate_charge_separation_effects(validator, content_index, errors)
