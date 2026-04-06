extends RefCounted
class_name ContentSnapshotFormalObitoSkillEffectContracts

const ObitoSkillContractsScript := preload("res://src/battle_core/content/formal_validators/obito/content_snapshot_formal_obito_skill_contracts.gd")

var _contracts = ObitoSkillContractsScript.new()

func validate(validator, content_index, errors: Array) -> void:
	_contracts.validate(validator, content_index, errors)
