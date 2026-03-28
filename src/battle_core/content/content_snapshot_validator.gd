extends RefCounted
class_name ContentSnapshotValidator

const CombatTypeChartEntryScript := preload("res://src/battle_core/content/combat_type_chart_entry.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")
const ForcedReplacePayloadScript := preload("res://src/battle_core/content/forced_replace_payload.gd")

var _content_index = null

func validate(content_index) -> Array:
    _content_index = content_index
    var errors: Array = _content_index.duplicate_registration_errors.duplicate()
    var allowed_targets: PackedStringArray = PackedStringArray([
        ContentSchemaScript.TARGET_ENEMY_ACTIVE,
        ContentSchemaScript.TARGET_SELF,
        ContentSchemaScript.TARGET_FIELD,
        ContentSchemaScript.TARGET_NONE,
    ])
    var allowed_damage_kinds: PackedStringArray = PackedStringArray([
        ContentSchemaScript.DAMAGE_KIND_PHYSICAL,
        ContentSchemaScript.DAMAGE_KIND_SPECIAL,
        ContentSchemaScript.DAMAGE_KIND_NONE,
    ])
    var allowed_scopes: PackedStringArray = PackedStringArray(["self", "target", "field"])
    var allowed_triggers: PackedStringArray = PackedStringArray([
        "battle_init",
        "turn_start",
        "turn_end",
        "on_cast",
        "on_hit",
        "on_miss",
        "on_enter",
        "on_exit",
        "on_switch",
        "on_faint",
        "on_kill",
        "on_matchup_changed",
    ])
    var allowed_power_bonus_sources: PackedStringArray = PackedStringArray(["", "mp_diff_clamped"])
    var allowed_chart_multipliers: Array[float] = [2.0, 1.0, 0.5]
    var regular_skill_refs: Dictionary = {}
    var ultimate_skill_refs: Dictionary = {}

    for combat_type_id in _content_index.combat_types.keys():
        var combat_type_definition = _content_index.combat_types[combat_type_id]
        if String(combat_type_definition.display_name).strip_edges().is_empty():
            errors.append("combat_type[%s].display_name must not be empty" % combat_type_id)

    for format_id in _content_index.battle_formats.keys():
        var format_definition = _content_index.battle_formats[format_id]
        if String(format_definition.visibility_mode).strip_edges().is_empty():
            errors.append("battle_format[%s].visibility_mode must not be empty" % format_id)
        var seen_chart_pairs: Dictionary = {}
        for chart_entry in format_definition.combat_type_chart:
            if chart_entry == null:
                errors.append("battle_format[%s].combat_type_chart contains null" % format_id)
                continue
            if not chart_entry is CombatTypeChartEntryScript:
                errors.append("battle_format[%s].combat_type_chart invalid type: %s" % [format_id, chart_entry])
                continue
            var attacker_type_id := String(chart_entry.atk).strip_edges()
            var defender_type_id := String(chart_entry.def).strip_edges()
            var multiplier := float(chart_entry.mul)
            if attacker_type_id.is_empty():
                errors.append("battle_format[%s].combat_type_chart missing atk" % format_id)
            elif not _content_index.combat_types.has(attacker_type_id):
                errors.append("battle_format[%s].combat_type_chart unknown atk: %s" % [format_id, attacker_type_id])
            if defender_type_id.is_empty():
                errors.append("battle_format[%s].combat_type_chart missing def" % format_id)
            elif not _content_index.combat_types.has(defender_type_id):
                errors.append("battle_format[%s].combat_type_chart unknown def: %s" % [format_id, defender_type_id])
            if not allowed_chart_multipliers.has(multiplier):
                errors.append("battle_format[%s].combat_type_chart invalid mul: %s" % [format_id, multiplier])
            if not attacker_type_id.is_empty() and not defender_type_id.is_empty():
                var chart_pair_key := "%s|%s" % [attacker_type_id, defender_type_id]
                if seen_chart_pairs.has(chart_pair_key):
                    errors.append("battle_format[%s].combat_type_chart duplicated pair: %s" % [format_id, chart_pair_key])
                else:
                    seen_chart_pairs[chart_pair_key] = true

    for unit_id in _content_index.units.keys():
        var unit_definition = _content_index.units[unit_id]
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
        _validate_effect_refs(errors, "skill[%s].effects_on_cast_ids" % skill_id, skill_definition.effects_on_cast_ids)
        _validate_effect_refs(errors, "skill[%s].effects_on_hit_ids" % skill_id, skill_definition.effects_on_hit_ids)
        _validate_effect_refs(errors, "skill[%s].effects_on_miss_ids" % skill_id, skill_definition.effects_on_miss_ids)
        _validate_effect_refs(errors, "skill[%s].effects_on_kill_ids" % skill_id, skill_definition.effects_on_kill_ids)

    for skill_id in regular_skill_refs.keys():
        if not _content_index.skills.has(skill_id):
            continue
        var skill_definition = _content_index.skills[skill_id]
        if int(skill_definition.priority) < -2 or int(skill_definition.priority) > 2:
            errors.append("skill[%s] used in unit.skill_ids must have priority in -2..2, got %d" % [skill_id, int(skill_definition.priority)])

    for skill_id in ultimate_skill_refs.keys():
        if not _content_index.skills.has(skill_id):
            continue
        var skill_definition = _content_index.skills[skill_id]
        if int(skill_definition.priority) != 5 and int(skill_definition.priority) != -5:
            errors.append("skill[%s] used as ultimate must have priority +5 or -5, got %d" % [skill_id, int(skill_definition.priority)])
        if regular_skill_refs.has(skill_id):
            errors.append("skill[%s] used as ultimate must not appear in any unit.skill_ids" % skill_id)

    for passive_id in _content_index.passive_skills.keys():
        var passive_definition = _content_index.passive_skills[passive_id]
        for trigger_name in passive_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("passive_skill[%s].trigger_names invalid: %s" % [passive_id, trigger_name])
        _validate_effect_refs(errors, "passive_skill[%s].effect_ids" % passive_id, passive_definition.effect_ids)

    for passive_id in _content_index.passive_items.keys():
        var passive_definition = _content_index.passive_items[passive_id]
        for trigger_name in passive_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("passive_item[%s].trigger_names invalid: %s" % [passive_id, trigger_name])
        _validate_effect_refs(errors, "passive_item[%s].effect_ids" % passive_id, passive_definition.effect_ids)
        _validate_effect_refs(errors, "passive_item[%s].always_on_effect_ids" % passive_id, passive_definition.always_on_effect_ids)
        if not passive_definition.on_receive_effect_ids.is_empty():
            errors.append("passive_item[%s].on_receive_effect_ids is disabled in current baseline and must be empty" % passive_id)
        _validate_effect_refs(errors, "passive_item[%s].on_turn_effect_ids" % passive_id, passive_definition.on_turn_effect_ids)

    for field_id in _content_index.fields.keys():
        var field_definition = _content_index.fields[field_id]
        _validate_effect_refs(errors, "field[%s].effect_ids" % field_id, field_definition.effect_ids)
        _validate_effect_refs(errors, "field[%s].on_expire_effect_ids" % field_id, field_definition.on_expire_effect_ids)
        _validate_effect_refs(errors, "field[%s].on_break_effect_ids" % field_id, field_definition.on_break_effect_ids)
        if int(field_definition.creator_accuracy_override) < -1 or int(field_definition.creator_accuracy_override) > 100:
            errors.append("field[%s].creator_accuracy_override out of range: %d" % [field_id, int(field_definition.creator_accuracy_override)])

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
        for trigger_name in effect_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("effect[%s].trigger_names invalid: %s" % [effect_id, trigger_name])
        _validate_effect_refs(errors, "effect[%s].on_expire_effect_ids" % effect_id, effect_definition.on_expire_effect_ids)
        for payload in effect_definition.payloads:
            _validate_payload(errors, effect_id, payload)
    _content_index = null
    return errors

func _validate_effect_refs(errors: Array, label: String, effect_ids: PackedStringArray) -> void:
    for effect_id in effect_ids:
        if not _content_index.effects.has(effect_id):
            errors.append("%s missing effect: %s" % [label, effect_id])

func _validate_payload(errors: Array, effect_id: String, payload) -> void:
    var allowed_stat_names: PackedStringArray = PackedStringArray([
        "attack",
        "defense",
        "sp_attack",
        "sp_defense",
        "speed",
    ])
    if payload == null:
        errors.append("effect[%s].payloads contains null" % effect_id)
        return
    if payload is DamagePayloadScript:
        if int(payload.amount) <= 0:
            errors.append("effect[%s].damage amount must be > 0, got %d" % [effect_id, int(payload.amount)])
        if bool(payload.use_formula):
            var formula_damage_kind := String(payload.damage_kind)
            if formula_damage_kind != ContentSchemaScript.DAMAGE_KIND_PHYSICAL and formula_damage_kind != ContentSchemaScript.DAMAGE_KIND_SPECIAL:
                errors.append("effect[%s].damage invalid damage_kind for formula: %s" % [effect_id, formula_damage_kind])
        elif not String(payload.combat_type_id).is_empty() and not _content_index.combat_types.has(String(payload.combat_type_id)):
            errors.append("effect[%s].damage combat_type_id missing combat type: %s" % [effect_id, String(payload.combat_type_id)])
        return
    if payload is HealPayloadScript:
        if bool(payload.use_percent):
            if int(payload.percent) < 1 or int(payload.percent) > 100:
                errors.append("effect[%s].heal percent out of range: %d" % [effect_id, int(payload.percent)])
        elif int(payload.amount) <= 0:
            errors.append("effect[%s].heal amount must be > 0, got %d" % [effect_id, int(payload.amount)])
        return
    if payload is ResourceModPayloadScript:
        if String(payload.resource_key) != "mp":
            errors.append("effect[%s].resource_mod invalid resource_key: %s" % [effect_id, payload.resource_key])
        return
    if payload is StatModPayloadScript:
        if not allowed_stat_names.has(String(payload.stat_name)):
            errors.append("effect[%s].stat_mod invalid stat_name: %s" % [effect_id, payload.stat_name])
        return
    if payload is ApplyFieldPayloadScript:
        if String(payload.field_definition_id).is_empty() or not _content_index.fields.has(payload.field_definition_id):
            errors.append("effect[%s].apply_field missing field: %s" % [effect_id, payload.field_definition_id])
        return
    if payload is ApplyEffectPayloadScript:
        if String(payload.effect_definition_id).is_empty() or not _content_index.effects.has(payload.effect_definition_id):
            errors.append("effect[%s].apply_effect missing effect: %s" % [effect_id, payload.effect_definition_id])
        return
    if payload is RemoveEffectPayloadScript:
        if String(payload.effect_definition_id).is_empty() or not _content_index.effects.has(payload.effect_definition_id):
            errors.append("effect[%s].remove_effect missing effect: %s" % [effect_id, payload.effect_definition_id])
        return
    if payload is RuleModPayloadScript:
        var rule_mod_errors = _validate_rule_mod_payload(payload)
        for error_msg in rule_mod_errors:
            errors.append("effect[%s].rule_mod invalid: %s" % [effect_id, error_msg])
        return
    if payload is ForcedReplacePayloadScript:
        if payload.scope != "self" and payload.scope != "target":
            errors.append("effect[%s].forced_replace invalid scope: %s" % [effect_id, payload.scope])
        if String(payload.selector_reason).strip_edges().is_empty():
            errors.append("effect[%s].forced_replace selector_reason must not be empty" % effect_id)
        return
    errors.append("effect[%s].payloads invalid type: %s" % [effect_id, payload])

func _validate_rule_mod_payload(rule_mod_payload) -> Array:
    var errors: Array = []
    var allowed_mod_kinds: PackedStringArray = PackedStringArray([
        ContentSchemaScript.RULE_MOD_FINAL_MOD,
        ContentSchemaScript.RULE_MOD_MP_REGEN,
        ContentSchemaScript.RULE_MOD_SKILL_LEGALITY,
    ])
    if not allowed_mod_kinds.has(rule_mod_payload.mod_kind):
        errors.append("mod_kind %s" % rule_mod_payload.mod_kind)
    var allowed_scopes: PackedStringArray = PackedStringArray(["self", "target", "field"])
    if not allowed_scopes.has(rule_mod_payload.scope):
        errors.append("scope %s" % rule_mod_payload.scope)
    var allowed_stacking: PackedStringArray = PackedStringArray([
        ContentSchemaScript.STACKING_NONE,
        ContentSchemaScript.STACKING_REFRESH,
        ContentSchemaScript.STACKING_REPLACE,
    ])
    if not allowed_stacking.has(rule_mod_payload.stacking):
        errors.append("stacking %s" % rule_mod_payload.stacking)
    if rule_mod_payload.decrement_on != "turn_start" and rule_mod_payload.decrement_on != "turn_end":
        errors.append("decrement_on %s" % rule_mod_payload.decrement_on)
    if rule_mod_payload.duration_mode != ContentSchemaScript.DURATION_TURNS and rule_mod_payload.duration_mode != ContentSchemaScript.DURATION_PERMANENT:
        errors.append("duration_mode %s" % rule_mod_payload.duration_mode)
    if rule_mod_payload.duration_mode == ContentSchemaScript.DURATION_TURNS and int(rule_mod_payload.duration) <= 0:
        errors.append("duration %s" % rule_mod_payload.duration)
    if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_FINAL_MOD:
        if rule_mod_payload.mod_op != "mul" and rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
            errors.append("mod_op %s" % rule_mod_payload.mod_op)
    elif rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_MP_REGEN:
        if rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
            errors.append("mod_op %s" % rule_mod_payload.mod_op)
    elif rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_SKILL_LEGALITY:
        if rule_mod_payload.mod_op != "allow" and rule_mod_payload.mod_op != "deny":
            errors.append("mod_op %s" % rule_mod_payload.mod_op)
    var dynamic_formula := String(rule_mod_payload.dynamic_value_formula)
    var dynamic_thresholds: PackedInt32Array = rule_mod_payload.dynamic_value_thresholds
    var dynamic_outputs: PackedFloat32Array = rule_mod_payload.dynamic_value_outputs
    if dynamic_formula.is_empty():
        if not dynamic_thresholds.is_empty() or not dynamic_outputs.is_empty():
            errors.append("dynamic value schema requires formula when thresholds/outputs are present")
    else:
        if dynamic_formula != ContentSchemaScript.RULE_MOD_VALUE_FORMULA_MATCHUP_BST_GAP_BAND:
            errors.append("dynamic_value_formula %s" % dynamic_formula)
        if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_SKILL_LEGALITY:
            errors.append("dynamic value formula is not allowed for skill_legality")
        if rule_mod_payload.scope == "field":
            errors.append("dynamic value formula is not allowed for field scope")
        if dynamic_thresholds.is_empty():
            errors.append("dynamic_value_thresholds must not be empty")
        if dynamic_outputs.is_empty():
            errors.append("dynamic_value_outputs must not be empty")
        if dynamic_thresholds.size() != dynamic_outputs.size():
            errors.append("dynamic_value_thresholds/dynamic_value_outputs size mismatch")
        var previous_threshold: Variant = null
        for threshold in dynamic_thresholds:
            if previous_threshold != null and int(threshold) <= int(previous_threshold):
                errors.append("dynamic_value_thresholds must be strictly ascending")
                break
            previous_threshold = threshold
    return errors
