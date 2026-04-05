extends "res://src/battle_core/content/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalGojoValidator

const GojoUnitPassiveContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_gojo_unit_passive_contracts.gd")
const GojoSkillEffectContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_gojo_skill_effect_contracts.gd")
const GojoUltimateDomainContractsScript := preload("res://src/battle_core/content/content_snapshot_formal_gojo_ultimate_domain_contracts.gd")

var _unit_passive_contracts = GojoUnitPassiveContractsScript.new()
var _skill_effect_contracts = GojoSkillEffectContractsScript.new()
var _ultimate_domain_contracts = GojoUltimateDomainContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_unit_passive_contracts.validate(self, content_index, errors)
	_skill_effect_contracts.validate(self, content_index, errors)
	_ultimate_domain_contracts.validate(self, content_index, errors)
