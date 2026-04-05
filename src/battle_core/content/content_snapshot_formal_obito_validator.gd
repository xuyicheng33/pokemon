extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalObitoValidator

const ObitoUnitPassiveContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_obito_unit_passive_contracts.gd")
const ObitoSkillContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_obito_skill_contracts.gd")
const ObitoUltimateContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_obito_ultimate_contracts.gd")

var _unit_passive_contracts = ObitoUnitPassiveContractsScript.new()
var _skill_contracts = ObitoSkillContractsScript.new()
var _ultimate_contracts = ObitoUltimateContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_unit_passive_contracts.validate(self, content_index, errors)
	_skill_contracts.validate(self, content_index, errors)
	_ultimate_contracts.validate(self, content_index, errors)
