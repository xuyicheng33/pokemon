extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalSukunaValidator

const SukunaUnitPassiveContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_sukuna_unit_passive_contracts.gd")
const SukunaSkillEffectContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_sukuna_skill_effect_contracts.gd")
const SukunaUltimateDomainContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_sukuna_ultimate_domain_contracts.gd")

var _unit_passive_contracts = SukunaUnitPassiveContractsScript.new()
var _skill_effect_contracts = SukunaSkillEffectContractsScript.new()
var _ultimate_domain_contracts = SukunaUltimateDomainContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_unit_passive_contracts.validate(self, content_index, errors)
	_skill_effect_contracts.validate(self, content_index, errors)
	_ultimate_domain_contracts.validate(self, content_index, errors)
