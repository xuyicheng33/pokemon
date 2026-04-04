extends RefCounted
class_name RuleModSchema

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

const ALLOWED_MOD_KINDS := ["final_mod", "mp_regen", "action_legality", "incoming_accuracy", "nullify_field_accuracy", "incoming_action_final_mod"]
const ALLOWED_SCOPES := ["self", "target", "field"]
const ALLOWED_STACKING := ["none", "refresh", "replace"]
const ACTION_LEGALITY_VALUES := ["all", "skill", "ultimate", "switch"]
const STACKING_KEY_SCHEMA_BY_KIND := {
    "final_mod": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op"],
    "mp_regen": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "source_stacking_key"],
    "action_legality": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "value"],
    "incoming_accuracy": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "source_stacking_key"],
    "nullify_field_accuracy": ["mod_kind", "scope", "owner_scope", "owner_id", "source_stacking_key"],
    "incoming_action_final_mod": ["mod_kind", "scope", "owner_scope", "owner_id", "mod_op", "source_stacking_key"],
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
    if bool(rule_mod_payload.persists_on_switch) and String(rule_mod_payload.scope) == "field":
        errors.append("persists_on_switch is not allowed for field scope")
    if rule_mod_payload.duration_mode == ContentSchemaScript.DURATION_TURNS and int(rule_mod_payload.duration) <= 0:
        errors.append("duration %s" % rule_mod_payload.duration)
    match String(rule_mod_payload.mod_kind):
        ContentSchemaScript.RULE_MOD_FINAL_MOD:
            if rule_mod_payload.mod_op != "mul" and rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
        ContentSchemaScript.RULE_MOD_MP_REGEN:
            if rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            if typeof(rule_mod_payload.value) != TYPE_INT:
                errors.append("mp_regen value must be int")
        ContentSchemaScript.RULE_MOD_ACTION_LEGALITY:
            if rule_mod_payload.mod_op != "allow" and rule_mod_payload.mod_op != "deny":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            _validate_action_legality_value(errors, rule_mod_payload, content_index)
        ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY:
            if rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            if typeof(rule_mod_payload.value) != TYPE_INT:
                errors.append("incoming_accuracy value must be int")
        ContentSchemaScript.RULE_MOD_NULLIFY_FIELD_ACCURACY:
            if rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            if typeof(rule_mod_payload.value) != TYPE_BOOL:
                errors.append("nullify_field_accuracy value must be bool")
        ContentSchemaScript.RULE_MOD_INCOMING_ACTION_FINAL_MOD:
            if rule_mod_payload.mod_op != "mul" and rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
                errors.append("mod_op %s" % rule_mod_payload.mod_op)
            if typeof(rule_mod_payload.value) != TYPE_INT and typeof(rule_mod_payload.value) != TYPE_FLOAT:
                errors.append("incoming_action_final_mod value must be number")
    _validate_incoming_action_filters(errors, rule_mod_payload, content_index)
    _validate_dynamic_value_schema(errors, rule_mod_payload)
    return errors

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
    if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_ACTION_LEGALITY \
    or rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY \
    or rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_NULLIFY_FIELD_ACCURACY \
    or rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_INCOMING_ACTION_FINAL_MOD:
        errors.append("dynamic value formula is not allowed for %s" % String(rule_mod_payload.mod_kind))
    if rule_mod_payload.scope == "field":
        errors.append("dynamic value formula is not allowed for field scope")
    if dynamic_thresholds.is_empty():
        errors.append("dynamic_value_thresholds must not be empty")
    if dynamic_outputs.is_empty():
        errors.append("dynamic_value_outputs must not be empty")
    if dynamic_thresholds.size() != dynamic_outputs.size():
        errors.append("dynamic_value_thresholds/dynamic_value_outputs size mismatch")
    if String(rule_mod_payload.mod_kind) == ContentSchemaScript.RULE_MOD_MP_REGEN:
        for output_value in dynamic_outputs:
            if not _is_integral_number(output_value):
                errors.append("mp_regen dynamic_value_outputs must be int-valued")
                break
        if not _is_integral_number(rule_mod_payload.dynamic_value_default):
            errors.append("mp_regen dynamic_value_default must be int-valued")
    var previous_threshold: Variant = null
    for threshold in dynamic_thresholds:
        if previous_threshold != null and int(threshold) <= int(previous_threshold):
            errors.append("dynamic_value_thresholds must be strictly ascending")
            break
        previous_threshold = threshold

func _is_integral_number(value) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    return is_equal_approx(float(value), float(int(value)))

func _validate_incoming_action_filters(errors: Array, rule_mod_payload, content_index) -> void:
    var command_filters: PackedStringArray = rule_mod_payload.required_incoming_command_types
    var combat_type_filters: PackedStringArray = rule_mod_payload.required_incoming_combat_type_ids
    if String(rule_mod_payload.mod_kind) != ContentSchemaScript.RULE_MOD_INCOMING_ACTION_FINAL_MOD:
        if not command_filters.is_empty():
            errors.append("required_incoming_command_types only allowed for incoming_action_final_mod")
        if not combat_type_filters.is_empty():
            errors.append("required_incoming_combat_type_ids only allowed for incoming_action_final_mod")
        return
    for command_type in command_filters:
        var normalized_command_type := String(command_type).strip_edges()
        if normalized_command_type.is_empty():
            errors.append("required_incoming_command_types must not contain empty entry")
            continue
        if normalized_command_type != ContentSchemaScript.ACTION_LEGALITY_SKILL \
        and normalized_command_type != ContentSchemaScript.ACTION_LEGALITY_ULTIMATE:
            errors.append("required_incoming_command_types invalid: %s" % normalized_command_type)
    for combat_type_id in combat_type_filters:
        var normalized_combat_type_id := String(combat_type_id).strip_edges()
        if normalized_combat_type_id.is_empty():
            errors.append("required_incoming_combat_type_ids must not contain empty entry")
            continue
        if content_index != null and not content_index.combat_types.has(normalized_combat_type_id):
            errors.append("required_incoming_combat_type_ids missing combat type: %s" % normalized_combat_type_id)
