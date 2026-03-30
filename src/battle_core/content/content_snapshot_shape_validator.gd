extends RefCounted
class_name ContentSnapshotShapeValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ContentSnapshotCatalogValidatorScript := preload("res://src/battle_core/content/content_snapshot_catalog_validator.gd")

var _content_index = null
var _payload_validator = null
var _catalog_validator = ContentSnapshotCatalogValidatorScript.new()

func validate(content_index, errors: Array, payload_validator) -> void:
    _content_index = content_index
    _payload_validator = payload_validator
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
    var allowed_scopes: PackedStringArray = PackedStringArray(["self", "target", "field"])
    var allowed_power_bonus_sources: PackedStringArray = PackedStringArray(["", "mp_diff_clamped"])
    var allowed_field_kinds: PackedStringArray = PackedStringArray([
        ContentSchemaScript.FIELD_KIND_NORMAL,
        ContentSchemaScript.FIELD_KIND_DOMAIN,
    ])
    var regular_skill_refs: Dictionary = {}
    var ultimate_skill_refs: Dictionary = {}

    _catalog_validator.validate(_content_index, errors)

    for unit_id in _content_index.units.keys():
        var unit_definition = _content_index.units[unit_id]
        if int(unit_definition.ultimate_points_required) < 0:
            errors.append("unit[%s].ultimate_points_required must be >= 0, got %d" % [unit_id, int(unit_definition.ultimate_points_required)])
        if int(unit_definition.ultimate_points_cap) < 0:
            errors.append("unit[%s].ultimate_points_cap must be >= 0, got %d" % [unit_id, int(unit_definition.ultimate_points_cap)])
        if int(unit_definition.ultimate_point_gain_on_regular_skill_cast) < 0:
            errors.append("unit[%s].ultimate_point_gain_on_regular_skill_cast must be >= 0, got %d" % [unit_id, int(unit_definition.ultimate_point_gain_on_regular_skill_cast)])
        if int(unit_definition.ultimate_points_cap) < int(unit_definition.ultimate_points_required):
            errors.append("unit[%s].ultimate_points_cap must be >= ultimate_points_required" % unit_id)
        if unit_definition.combat_type_ids.size() > 2:
            errors.append("unit[%s].combat_type_ids must contain at most 2 entries, got %d" % [unit_id, unit_definition.combat_type_ids.size()])
        var seen_unit_types: Dictionary = {}
        for combat_type_id in unit_definition.combat_type_ids:
            var normalized_type_id := String(combat_type_id).strip_edges()
            if normalized_type_id.is_empty():
                errors.append("unit[%s].combat_type_ids must not contain empty entry" % unit_id)
                continue
            if seen_unit_types.has(normalized_type_id):
                errors.append("unit[%s].combat_type_ids duplicated type: %s" % [unit_id, normalized_type_id])
                continue
            seen_unit_types[normalized_type_id] = true
            if not _content_index.combat_types.has(normalized_type_id):
                errors.append("unit[%s].combat_type_ids missing combat type: %s" % [unit_id, normalized_type_id])
        if unit_definition.skill_ids.size() != 3:
            errors.append("unit[%s].skill_ids must contain exactly 3 entries, got %d" % [unit_id, unit_definition.skill_ids.size()])
        for skill_id in unit_definition.skill_ids:
            regular_skill_refs[skill_id] = true
            if not _content_index.skills.has(skill_id):
                errors.append("unit[%s].skill_ids missing skill: %s" % [unit_id, skill_id])
        if not unit_definition.candidate_skill_ids.is_empty():
            if unit_definition.candidate_skill_ids.size() < 3:
                errors.append("unit[%s].candidate_skill_ids must contain at least 3 entries, got %d" % [unit_id, unit_definition.candidate_skill_ids.size()])
            var seen_candidate_skills: Dictionary = {}
            for candidate_skill_id in unit_definition.candidate_skill_ids:
                var normalized_candidate_skill_id := String(candidate_skill_id).strip_edges()
                regular_skill_refs[normalized_candidate_skill_id] = true
                if normalized_candidate_skill_id.is_empty():
                    errors.append("unit[%s].candidate_skill_ids must not contain empty entry" % unit_id)
                    continue
                if seen_candidate_skills.has(normalized_candidate_skill_id):
                    errors.append("unit[%s].candidate_skill_ids duplicated skill: %s" % [unit_id, normalized_candidate_skill_id])
                    continue
                seen_candidate_skills[normalized_candidate_skill_id] = true
                if not _content_index.skills.has(normalized_candidate_skill_id):
                    errors.append("unit[%s].candidate_skill_ids missing skill: %s" % [unit_id, normalized_candidate_skill_id])
                if normalized_candidate_skill_id == unit_definition.ultimate_skill_id and not unit_definition.ultimate_skill_id.is_empty():
                    errors.append("unit[%s].candidate_skill_ids must not include ultimate_skill_id: %s" % [unit_id, normalized_candidate_skill_id])
            for default_skill_id in unit_definition.skill_ids:
                if not unit_definition.candidate_skill_ids.has(default_skill_id):
                    errors.append("unit[%s].candidate_skill_ids must include default skill: %s" % [unit_id, default_skill_id])
        if not unit_definition.ultimate_skill_id.is_empty():
            ultimate_skill_refs[unit_definition.ultimate_skill_id] = true
            if not _content_index.skills.has(unit_definition.ultimate_skill_id):
                errors.append("unit[%s].ultimate_skill_id missing skill: %s" % [unit_id, unit_definition.ultimate_skill_id])
            if unit_definition.skill_ids.has(unit_definition.ultimate_skill_id):
                errors.append("unit[%s].ultimate_skill_id duplicated in skill_ids: %s" % [unit_id, unit_definition.ultimate_skill_id])
        elif int(unit_definition.ultimate_points_required) != 0 \
        or int(unit_definition.ultimate_points_cap) != 0 \
        or int(unit_definition.ultimate_point_gain_on_regular_skill_cast) != 0:
            errors.append("unit[%s].ultimate point config requires ultimate_skill_id" % unit_id)
        if not unit_definition.passive_skill_id.is_empty() and not _content_index.passive_skills.has(unit_definition.passive_skill_id):
            errors.append("unit[%s].passive_skill_id missing passive skill: %s" % [unit_id, unit_definition.passive_skill_id])
        if not unit_definition.passive_item_id.is_empty() and not _content_index.passive_items.has(unit_definition.passive_item_id):
            errors.append("unit[%s].passive_item_id missing passive item: %s" % [unit_id, unit_definition.passive_item_id])

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

    for passive_id in _content_index.passive_skills.keys():
        var passive_definition = _content_index.passive_skills[passive_id]
        _payload_validator.validate_effect_refs(errors, "passive_skill[%s].effect_ids" % passive_id, passive_definition.effect_ids, _content_index.effects)

    for passive_id in _content_index.passive_items.keys():
        var passive_definition = _content_index.passive_items[passive_id]
        _payload_validator.validate_effect_refs(errors, "passive_item[%s].effect_ids" % passive_id, passive_definition.effect_ids, _content_index.effects)
        _payload_validator.validate_effect_refs(errors, "passive_item[%s].always_on_effect_ids" % passive_id, passive_definition.always_on_effect_ids, _content_index.effects)
        if not passive_definition.on_receive_effect_ids.is_empty():
            errors.append("passive_item[%s].on_receive_effect_ids is disabled in current baseline and must be empty" % passive_id)
        _payload_validator.validate_effect_refs(errors, "passive_item[%s].on_turn_effect_ids" % passive_id, passive_definition.on_turn_effect_ids, _content_index.effects)

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

    for field_id in _content_index.fields.keys():
        var field_definition = _content_index.fields[field_id]
        var field_kind := String(field_definition.field_kind)
        if not allowed_field_kinds.has(field_kind):
            errors.append("field[%s].field_kind invalid: %s" % [field_id, String(field_definition.field_kind)])
        _payload_validator.validate_effect_refs(errors, "field[%s].effect_ids" % field_id, field_definition.effect_ids, _content_index.effects)
        _payload_validator.validate_effect_refs(errors, "field[%s].on_expire_effect_ids" % field_id, field_definition.on_expire_effect_ids, _content_index.effects)
        _payload_validator.validate_effect_refs(errors, "field[%s].on_break_effect_ids" % field_id, field_definition.on_break_effect_ids, _content_index.effects)
        if int(field_definition.creator_accuracy_override) < -1 or int(field_definition.creator_accuracy_override) > 100:
            errors.append("field[%s].creator_accuracy_override out of range: %d" % [field_id, int(field_definition.creator_accuracy_override)])
        if field_kind == ContentSchemaScript.FIELD_KIND_DOMAIN:
            if field_definition.effect_ids.is_empty():
                errors.append("field[%s].effect_ids must not be empty for domain field" % field_id)
            if field_definition.on_expire_effect_ids.is_empty():
                errors.append("field[%s].on_expire_effect_ids must not be empty for domain field" % field_id)
            if field_definition.on_break_effect_ids.is_empty():
                errors.append("field[%s].on_break_effect_ids must not be empty for domain field" % field_id)

    for effect_id in _content_index.effects.keys():
        var effect_definition = _content_index.effects[effect_id]
        if not allowed_scopes.has(effect_definition.scope):
            errors.append("effect[%s].scope invalid: %s" % [effect_id, effect_definition.scope])
        if int(effect_definition.priority) < -5 or int(effect_definition.priority) > 5:
            errors.append("effect[%s].priority out of range: %d" % [effect_id, int(effect_definition.priority)])
        if effect_definition.duration_mode != ContentSchemaScript.DURATION_TURNS and effect_definition.duration_mode != ContentSchemaScript.DURATION_PERMANENT:
            errors.append("effect[%s].duration_mode invalid: %s" % [effect_id, effect_definition.duration_mode])
        if effect_definition.duration_mode == ContentSchemaScript.DURATION_TURNS:
            if int(effect_definition.duration) <= 0:
                errors.append("effect[%s].duration must be > 0 for turns mode" % effect_id)
            if effect_definition.decrement_on != "turn_start" and effect_definition.decrement_on != "turn_end":
                errors.append("effect[%s].decrement_on invalid: %s" % [effect_id, effect_definition.decrement_on])
        if effect_definition.duration_mode == ContentSchemaScript.DURATION_PERMANENT and not String(effect_definition.decrement_on).is_empty():
            errors.append("effect[%s].decrement_on must be empty for permanent effects" % effect_id)
        if effect_definition.stacking != ContentSchemaScript.STACKING_NONE \
        and effect_definition.stacking != ContentSchemaScript.STACKING_REFRESH \
        and effect_definition.stacking != ContentSchemaScript.STACKING_REPLACE \
        and effect_definition.stacking != ContentSchemaScript.STACKING_STACK:
            errors.append("effect[%s].stacking invalid: %s" % [effect_id, effect_definition.stacking])
        _validate_required_target_effects(errors, effect_id, effect_definition)
        _payload_validator.validate_effect_refs(errors, "effect[%s].on_expire_effect_ids" % effect_id, effect_definition.on_expire_effect_ids, _content_index.effects)
        for payload in effect_definition.payloads:
            _payload_validator.validate_payload(errors, effect_id, payload, _content_index)

    _payload_validator = null
    _content_index = null

func _validate_required_target_effects(errors: Array, effect_id: String, effect_definition) -> void:
    if effect_definition.required_target_effects.is_empty():
        return
    if effect_definition.scope != "target":
        errors.append("effect[%s].required_target_effects requires scope=target" % effect_id)
    var seen_required_effects: Dictionary = {}
    for required_effect_id in effect_definition.required_target_effects:
        var normalized_effect_id := String(required_effect_id).strip_edges()
        if normalized_effect_id.is_empty():
            errors.append("effect[%s].required_target_effects must not contain empty entry" % effect_id)
            continue
        if seen_required_effects.has(normalized_effect_id):
            errors.append("effect[%s].required_target_effects duplicated effect: %s" % [effect_id, normalized_effect_id])
            continue
        seen_required_effects[normalized_effect_id] = true
        if not _content_index.effects.has(normalized_effect_id):
            errors.append("effect[%s].required_target_effects missing effect: %s" % [effect_id, normalized_effect_id])
