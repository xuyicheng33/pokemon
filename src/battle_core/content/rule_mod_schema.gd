extends RefCounted
class_name RuleModSchema

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

const ALLOWED_MOD_KINDS := ["final_mod", "mp_regen", "skill_legality", "action_legality", "incoming_accuracy"]
const ALLOWED_SCOPES := ["self", "target", "field"]
const ALLOWED_STACKING := ["none", "refresh", "replace"]
const ACTION_LEGALITY_VALUES := ["all", "skill", "ultimate", "switch"]
const STACKING_KEY_SCHEMA_BY_KIND := {
    "final_mod": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op"],
    "mp_regen": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op"],
    "skill_legality": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "value"],
    "action_legality": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "value"],
    "incoming_accuracy": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op"],
}

func validate_payload(rule_mod_payload, content_index = null) -> Array:
    var errors: Array = []
    if not ALLOWED_MOD_KINDS.has(rule_mod_payload.mod_kind):
        errors.append("mod_kind %s" % rule_mod_payload.mod_kind)
    if not ALLOWED_SCOPES.has(rule_mod_payload.scope):
        errors.append("scope %s" % rule_mod_payload.scope)
    if not ALLOWED_STACKING.has(rule_mod_payload.stacking):
        errors.append("stacking %s" % rule_mod_payload.stacking)
    if rule_mod_payload.decrement_on != "turn_start" and rule_mod_payload.decrement_on != "turn_end":
        errors.append("decrement_on %s" % rule_mod_payload.decrement_on)
    if rule_mod_payload.duration_mode != ContentSchemaScript.DURATION_TURNS and rule_mod_payload.duration_mode != ContentSchemaScript.DURATION_PERMANENT:
        errors.append("duration_mode %s" % rule_mod_payload.duration_mode)
    if rule_mod_payload.duration_mode == ContentSchemaScript.DURATION_TURNS and int(rule_mod_payload.duration) <= 0:
        errors.append("duration %s" % rule_mod_payload.duration)
    match String(rule_mod_payload.mod_kind):
        ContentSchemaScript.RULE_MOD_FINAL_MOD:
            if rule_mod_payload.mod_op != "mul" and rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
        ContentSchemaScript.RULE_MOD_MP_REGEN:
            if rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
        ContentSchemaScript.RULE_MOD_SKILL_LEGALITY:
            if rule_mod_payload.mod_op != "allow" and rule_mod_payload.mod_op != "deny":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            _validate_skill_legality_value(errors, rule_mod_payload, content_index)
        ContentSchemaScript.RULE_MOD_ACTION_LEGALITY:
            if rule_mod_payload.mod_op != "allow" and rule_mod_payload.mod_op != "deny":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            _validate_action_legality_value(errors, rule_mod_payload, content_index)
        ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY:
            if rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            if typeof(rule_mod_payload.value) != TYPE_INT:
                errors.append("incoming_accuracy value must be int")
    _validate_dynamic_value_schema(errors, rule_mod_payload)
    return errors

func _validate_skill_legality_value(errors: Array, rule_mod_payload, content_index) -> void:
    if typeof(rule_mod_payload.value) != TYPE_STRING:
        errors.append("skill_legality value must be String")
        return
    var skill_id := String(rule_mod_payload.value).strip_edges()
    if skill_id.is_empty():
        return
    if content_index != null and not content_index.skills.has(skill_id):
        errors.append("skill_legality value missing skill: %s" % skill_id)

func _validate_action_legality_value(errors: Array, rule_mod_payload, content_index) -> void:
    if typeof(rule_mod_payload.value) != TYPE_STRING:
        errors.append("action_legality value must be String")
        return
    var action_value := String(rule_mod_payload.value).strip_edges()
    if action_value.is_empty():
        errors.append("action_legality value must not be empty")
        return
    if ACTION_LEGALITY_VALUES.has(action_value):
        return
    if content_index != null and not content_index.skills.has(action_value):
        errors.append("action_legality value missing skill: %s" % action_value)

func _validate_dynamic_value_schema(errors: Array, rule_mod_payload) -> void:
    var dynamic_formula := String(rule_mod_payload.dynamic_value_formula)
    var dynamic_thresholds: PackedInt32Array = rule_mod_payload.dynamic_value_thresholds
    var dynamic_outputs: PackedFloat32Array = rule_mod_payload.dynamic_value_outputs
    if dynamic_formula.is_empty():
        if not dynamic_thresholds.is_empty() or not dynamic_outputs.is_empty():
            errors.append("dynamic value schema requires formula when thresholds/outputs are present")
        return
    if dynamic_formula != ContentSchemaScript.RULE_MOD_VALUE_FORMULA_MATCHUP_BST_GAP_BAND:
        errors.append("dynamic_value_formula %s" % dynamic_formula)
    if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_SKILL_LEGALITY \
    or rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_ACTION_LEGALITY \
    or rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY:
        errors.append("dynamic value formula is not allowed for %s" % String(rule_mod_payload.mod_kind))
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
