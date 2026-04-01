extends RefCounted
class_name ContentSnapshotSkillValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")

var _content_index = null
var _payload_validator = null

func validate(content_index, errors: Array, payload_validator, regular_skill_refs: Dictionary, ultimate_skill_refs: Dictionary) -> void:
    _content_index = content_index
    _payload_validator = payload_validator
    _validate_skills(errors)
    _validate_passive_skills(errors)
    _validate_passive_items(errors)
    _validate_skill_role_constraints(errors, regular_skill_refs, ultimate_skill_refs)
    _payload_validator = null
    _content_index = null

func _validate_skills(errors: Array) -> void:
    var allowed_targets := PackedStringArray([
        ContentSchemaScript.TARGET_ENEMY_ACTIVE,
        ContentSchemaScript.TARGET_SELF,
        ContentSchemaScript.TARGET_FIELD,
        ContentSchemaScript.TARGET_NONE,
    ])
    var allowed_damage_kinds := PackedStringArray([
        ContentSchemaScript.DAMAGE_KIND_PHYSICAL,
        ContentSchemaScript.DAMAGE_KIND_SPECIAL,
        ContentSchemaScript.DAMAGE_KIND_NONE,
    ])
    var allowed_power_bonus_sources := PowerBonusSourceRegistryScript.registered_sources()
    for skill_id in _content_index.skills.keys():
        var skill_definition = _content_index.skills[skill_id]
        if not String(skill_definition.combat_type_id).is_empty() and not _content_index.combat_types.has(skill_definition.combat_type_id):
            errors.append("skill[%s].combat_type_id missing combat type: %s" % [skill_id, skill_definition.combat_type_id])
        if not allowed_targets.has(skill_definition.targeting):
            errors.append("skill[%s].targeting invalid: %s" % [skill_id, skill_definition.targeting])
        if not allowed_damage_kinds.has(skill_definition.damage_kind):
            errors.append("skill[%s].damage_kind invalid: %s" % [skill_id, skill_definition.damage_kind])
        if int(skill_definition.accuracy) < 0 or int(skill_definition.accuracy) > 100:
            errors.append("skill[%s].accuracy out of range: %d" % [skill_id, int(skill_definition.accuracy)])
        if int(skill_definition.mp_cost) < 0:
            errors.append("skill[%s].mp_cost must be >= 0, got %d" % [skill_id, int(skill_definition.mp_cost)])
        if int(skill_definition.priority) < -5 or int(skill_definition.priority) > 5:
            errors.append("skill[%s].priority out of range: %d" % [skill_id, int(skill_definition.priority)])
        if not allowed_power_bonus_sources.has(String(skill_definition.power_bonus_source)):
            errors.append("skill[%s].power_bonus_source invalid: %s" % [skill_id, String(skill_definition.power_bonus_source)])
        if skill_definition.damage_kind != ContentSchemaScript.DAMAGE_KIND_NONE and int(skill_definition.power) <= 0:
            errors.append("skill[%s].power must be > 0 for damage skills, got %d" % [skill_id, int(skill_definition.power)])
        _payload_validator.validate_effect_refs(errors, "skill[%s].effects_on_cast_ids" % skill_id, skill_definition.effects_on_cast_ids, _content_index.effects)
        _payload_validator.validate_effect_refs(errors, "skill[%s].effects_on_hit_ids" % skill_id, skill_definition.effects_on_hit_ids, _content_index.effects)
        _payload_validator.validate_effect_refs(errors, "skill[%s].effects_on_miss_ids" % skill_id, skill_definition.effects_on_miss_ids, _content_index.effects)
        _payload_validator.validate_effect_refs(errors, "skill[%s].effects_on_kill_ids" % skill_id, skill_definition.effects_on_kill_ids, _content_index.effects)
        var has_domain_apply_field: bool = _content_index.skill_applies_domain_field(skill_id)
        if bool(skill_definition.is_domain_skill) and not has_domain_apply_field:
            errors.append("skill[%s].is_domain_skill requires apply_field payload to domain field" % skill_id)
        if has_domain_apply_field and not bool(skill_definition.is_domain_skill):
            errors.append("skill[%s] applies domain field and must set is_domain_skill=true" % skill_id)

func _validate_passive_skills(errors: Array) -> void:
    for passive_id in _content_index.passive_skills.keys():
        var passive_definition = _content_index.passive_skills[passive_id]
        _payload_validator.validate_effect_refs(errors, "passive_skill[%s].effect_ids" % passive_id, passive_definition.effect_ids, _content_index.effects)

func _validate_passive_items(errors: Array) -> void:
    for passive_id in _content_index.passive_items.keys():
        var passive_definition = _content_index.passive_items[passive_id]
        _payload_validator.validate_effect_refs(errors, "passive_item[%s].effect_ids" % passive_id, passive_definition.effect_ids, _content_index.effects)
        _payload_validator.validate_effect_refs(errors, "passive_item[%s].always_on_effect_ids" % passive_id, passive_definition.always_on_effect_ids, _content_index.effects)
        if not passive_definition.on_receive_effect_ids.is_empty():
            errors.append("passive_item[%s].on_receive_effect_ids is disabled in current baseline and must be empty" % passive_id)
        _payload_validator.validate_effect_refs(errors, "passive_item[%s].on_turn_effect_ids" % passive_id, passive_definition.on_turn_effect_ids, _content_index.effects)

func _validate_skill_role_constraints(errors: Array, regular_skill_refs: Dictionary, ultimate_skill_refs: Dictionary) -> void:
    for skill_id in regular_skill_refs.keys():
        if not _content_index.skills.has(skill_id):
            continue
        var regular_skill = _content_index.skills[skill_id]
        if int(regular_skill.priority) < -2 or int(regular_skill.priority) > 2:
            errors.append("skill[%s] used in unit.skill_ids must have priority in -2..2, got %d" % [skill_id, int(regular_skill.priority)])
    for skill_id in ultimate_skill_refs.keys():
        if not _content_index.skills.has(skill_id):
            continue
        var ultimate_skill = _content_index.skills[skill_id]
        if int(ultimate_skill.priority) != 5 and int(ultimate_skill.priority) != -5:
            errors.append("skill[%s] used as ultimate must have priority +5 or -5, got %d" % [skill_id, int(ultimate_skill.priority)])
        if regular_skill_refs.has(skill_id):
            errors.append("skill[%s] used as ultimate must not appear in any unit.skill_ids" % skill_id)
