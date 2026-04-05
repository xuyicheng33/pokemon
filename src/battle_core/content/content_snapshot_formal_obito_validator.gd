extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalObitoValidator

const ObitoUnitPassiveContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_obito_unit_passive_contracts.gd")
const ObitoSkillEffectContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_obito_skill_effect_contracts.gd")
const ObitoUltimateDomainContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_obito_ultimate_domain_contracts.gd")

var _unit_passive_contracts = ObitoUnitPassiveContractsScript.new()
var _skill_effect_contracts = ObitoSkillEffectContractsScript.new()
var _ultimate_domain_contracts = ObitoUltimateDomainContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_unit_passive_contracts.validate(self, content_index, errors)
	_skill_effect_contracts.validate(self, content_index, errors)
	_ultimate_domain_contracts.validate(self, content_index, errors)
