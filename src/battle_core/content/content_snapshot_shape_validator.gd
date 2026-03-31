extends RefCounted
class_name ContentSnapshotShapeValidator

const ContentSnapshotCatalogValidatorScript := preload("res://src/battle_core/content/content_snapshot_catalog_validator.gd")
const ContentSnapshotSkillValidatorScript := preload("res://src/battle_core/content/content_snapshot_skill_validator.gd")
const ContentSnapshotUnitValidatorScript := preload("res://src/battle_core/content/content_snapshot_unit_validator.gd")
const ContentSnapshotFieldValidatorScript := preload("res://src/battle_core/content/content_snapshot_field_validator.gd")
const ContentSnapshotEffectValidatorScript := preload("res://src/battle_core/content/content_snapshot_effect_validator.gd")
const ContentSnapshotFormalCharacterValidatorScript := preload("res://src/battle_core/content/content_snapshot_formal_character_validator.gd")

var _content_index = null
var _payload_validator = null
var _catalog_validator = ContentSnapshotCatalogValidatorScript.new()
var _skill_validator = ContentSnapshotSkillValidatorScript.new()
var _unit_validator = ContentSnapshotUnitValidatorScript.new()
var _field_validator = ContentSnapshotFieldValidatorScript.new()
var _effect_validator = ContentSnapshotEffectValidatorScript.new()
var _formal_character_validator = ContentSnapshotFormalCharacterValidatorScript.new()

func validate(content_index, errors: Array, payload_validator) -> void:
    _content_index = content_index
    _payload_validator = payload_validator
    var regular_skill_refs: Dictionary = {}
    var ultimate_skill_refs: Dictionary = {}

    _catalog_validator.validate(_content_index, errors)
    _unit_validator.validate_units(_content_index, errors, regular_skill_refs, ultimate_skill_refs)
    _skill_validator.validate(_content_index, errors, _payload_validator, regular_skill_refs, ultimate_skill_refs)
    _field_validator.validate(_content_index, errors, _payload_validator)
    _effect_validator.validate(_content_index, errors, _payload_validator)
    _formal_character_validator.validate(_content_index, errors)

    _payload_validator = null
    _content_index = null
