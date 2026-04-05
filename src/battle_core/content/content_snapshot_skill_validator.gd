extends RefCounted
class_name ContentSnapshotSkillValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const PowerBonusSourceRegistryScript := preload("res://src/battle_core/content/power_bonus_source_registry.gd")
const SkillDamageSegmentScript := preload("res://src/battle_core/content/skill_damage_segment.gd")

var _content_index = null
var _payload_validator = null
const EFFECT_STACK_SUM := PowerBonusSourceRegistryScript.EFFECT_STACK_SUM

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
        _validate_power_bonus_contract(errors, skill_id, skill_definition)
        _validate_execute_contract(errors, skill_id, skill_definition)
        _validate_damage_segments(errors, skill_id, skill_definition, allowed_damage_kinds)
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

func _validate_power_bonus_contract(errors: Array, skill_id: String, skill_definition) -> void:
    if String(skill_definition.power_bonus_source) != EFFECT_STACK_SUM:
        return
    var has_any_effect_id := false
    for effect_id in skill_definition.power_bonus_self_effect_ids:
        var normalized_effect_id := String(effect_id).strip_edges()
        if normalized_effect_id.is_empty():
            errors.append("skill[%s].power_bonus_self_effect_ids must not contain empty entry" % skill_id)
            continue
        has_any_effect_id = true
        if not _content_index.effects.has(normalized_effect_id):
            errors.append("skill[%s].power_bonus_self_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
    for effect_id in skill_definition.power_bonus_target_effect_ids:
        var normalized_effect_id := String(effect_id).strip_edges()
        if normalized_effect_id.is_empty():
            errors.append("skill[%s].power_bonus_target_effect_ids must not contain empty entry" % skill_id)
            continue
        has_any_effect_id = true
        if not _content_index.effects.has(normalized_effect_id):
            errors.append("skill[%s].power_bonus_target_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
    if not has_any_effect_id:
        errors.append("skill[%s].effect_stack_sum requires at least one power bonus effect id" % skill_id)
    if int(skill_definition.power_bonus_per_stack) <= 0:
        errors.append("skill[%s].power_bonus_per_stack must be > 0 for effect_stack_sum, got %d" % [skill_id, int(skill_definition.power_bonus_per_stack)])

func _validate_execute_contract(errors: Array, skill_id: String, skill_definition) -> void:
    var execute_ratio := float(skill_definition.execute_target_hp_ratio_lte)
    var execute_required_total_stacks := int(skill_definition.execute_required_total_stacks)
    var has_execute_config: bool = execute_ratio > 0.0 or execute_required_total_stacks > 0 \
        or not skill_definition.execute_self_effect_ids.is_empty() \
        or not skill_definition.execute_target_effect_ids.is_empty()
    if execute_ratio < 0.0 or execute_ratio > 1.0:
        errors.append("skill[%s].execute_target_hp_ratio_lte out of range: %s" % [skill_id, var_to_str(execute_ratio)])
    if execute_required_total_stacks < 0:
        errors.append("skill[%s].execute_required_total_stacks must be >= 0, got %d" % [skill_id, execute_required_total_stacks])
    if not has_execute_config:
        return
    if skill_definition.targeting != ContentSchemaScript.TARGET_ENEMY_ACTIVE:
        errors.append("skill[%s].execute contract requires targeting=enemy_active_slot" % skill_id)
    if skill_definition.damage_kind == ContentSchemaScript.DAMAGE_KIND_NONE and skill_definition.damage_segments.is_empty():
        errors.append("skill[%s].execute contract requires damage skill" % skill_id)
    var has_execute_effect_id := false
    for effect_id in skill_definition.execute_self_effect_ids:
        var normalized_effect_id := String(effect_id).strip_edges()
        if normalized_effect_id.is_empty():
            errors.append("skill[%s].execute_self_effect_ids must not contain empty entry" % skill_id)
            continue
        has_execute_effect_id = true
        if not _content_index.effects.has(normalized_effect_id):
            errors.append("skill[%s].execute_self_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
    for effect_id in skill_definition.execute_target_effect_ids:
        var normalized_effect_id := String(effect_id).strip_edges()
        if normalized_effect_id.is_empty():
            errors.append("skill[%s].execute_target_effect_ids must not contain empty entry" % skill_id)
            continue
        has_execute_effect_id = true
        if not _content_index.effects.has(normalized_effect_id):
            errors.append("skill[%s].execute_target_effect_ids missing effect: %s" % [skill_id, normalized_effect_id])
    if execute_required_total_stacks > 0 and not has_execute_effect_id:
        errors.append("skill[%s].execute_required_total_stacks requires execute effect ids" % skill_id)

func _validate_damage_segments(errors: Array, skill_id: String, skill_definition, allowed_damage_kinds: PackedStringArray) -> void:
    if skill_definition.damage_segments.is_empty():
        return
    if skill_definition.targeting != ContentSchemaScript.TARGET_ENEMY_ACTIVE:
        errors.append("skill[%s].damage_segments requires targeting=enemy_active_slot" % skill_id)
    if skill_definition.damage_kind == ContentSchemaScript.DAMAGE_KIND_NONE:
        errors.append("skill[%s].damage_segments requires top-level damage_kind != none" % skill_id)
    for segment_index in range(skill_definition.damage_segments.size()):
        var raw_segment = skill_definition.damage_segments[segment_index]
        if raw_segment == null or not raw_segment is SkillDamageSegmentScript:
            errors.append("skill[%s].damage_segments[%d] invalid type" % [skill_id, segment_index])
            continue
        var segment = raw_segment as SkillDamageSegmentScript
        if int(segment.repeat_count) <= 0:
            errors.append("skill[%s].damage_segments[%d].repeat_count must be > 0, got %d" % [skill_id, segment_index, int(segment.repeat_count)])
        if int(segment.power) <= 0:
            errors.append("skill[%s].damage_segments[%d].power must be > 0, got %d" % [skill_id, segment_index, int(segment.power)])
        if not allowed_damage_kinds.has(String(segment.damage_kind)) or String(segment.damage_kind) == ContentSchemaScript.DAMAGE_KIND_NONE:
            errors.append("skill[%s].damage_segments[%d].damage_kind invalid: %s" % [skill_id, segment_index, String(segment.damage_kind)])
        if not String(segment.combat_type_id).is_empty() and not _content_index.combat_types.has(String(segment.combat_type_id)):
            errors.append("skill[%s].damage_segments[%d].combat_type_id missing combat type: %s" % [skill_id, segment_index, String(segment.combat_type_id)])

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
