extends RefCounted
class_name ContentPayloadValidator

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

func validate_effect_refs(errors: Array, label: String, effect_ids: PackedStringArray, effects: Dictionary) -> void:
    for effect_id in effect_ids:
        if not effects.has(effect_id):
            errors.append("%s missing effect: %s" % [label, effect_id])

func validate_payload(errors: Array, effect_id: String, payload, content_index) -> void:
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
        elif not String(payload.combat_type_id).is_empty() and not content_index.combat_types.has(String(payload.combat_type_id)):
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
        if String(payload.field_definition_id).is_empty() or not content_index.fields.has(payload.field_definition_id):
            errors.append("effect[%s].apply_field missing field: %s" % [effect_id, payload.field_definition_id])
        return
    if payload is ApplyEffectPayloadScript:
        if String(payload.effect_definition_id).is_empty() or not content_index.effects.has(payload.effect_definition_id):
            errors.append("effect[%s].apply_effect missing effect: %s" % [effect_id, payload.effect_definition_id])
        return
    if payload is RemoveEffectPayloadScript:
        if String(payload.effect_definition_id).is_empty() or not content_index.effects.has(payload.effect_definition_id):
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
