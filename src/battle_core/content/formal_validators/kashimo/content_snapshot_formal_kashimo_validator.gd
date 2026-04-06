extends "res://src/battle_core/content/formal_validators/shared/content_snapshot_formal_character_validator_base.gd"
class_name ContentSnapshotFormalKashimoValidator

const KashimoUnitPassiveContractsScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_unit_passive_contracts.gd")
const KashimoSkillEffectContractsScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_skill_effect_contracts.gd")
const KashimoUltimateDomainContractsScript := preload("res://src/battle_core/content/formal_validators/kashimo/content_snapshot_formal_kashimo_ultimate_domain_contracts.gd")

var _unit_passive_contracts = KashimoUnitPassiveContractsScript.new()
var _skill_effect_contracts = KashimoSkillEffectContractsScript.new()
var _ultimate_domain_contracts = KashimoUltimateDomainContractsScript.new()

func validate(content_index, errors: Array) -> void:
	_unit_passive_contracts.validate(self, content_index, errors)
	_skill_effect_contracts.validate(self, content_index, errors)
	_ultimate_domain_contracts.validate(self, content_index, errors)
