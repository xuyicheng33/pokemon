extends RefCounted
class_name ContentSnapshotEffectValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

func validate(content_index, errors: Array, payload_validator) -> void:
    var allowed_scopes := PackedStringArray(["self", "target", "field"])
    for effect_id in content_index.effects.keys():
        var effect_definition = content_index.effects[effect_id]
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
        if effect_definition.stacking == ContentSchemaScript.STACKING_STACK:
            if int(effect_definition.max_stacks) != -1 and int(effect_definition.max_stacks) <= 0:
                errors.append("effect[%s].max_stacks must be positive or -1 for stack effects, got %d" % [effect_id, int(effect_definition.max_stacks)])
        elif int(effect_definition.max_stacks) != -1:
            errors.append("effect[%s].max_stacks only allowed when stacking=stack, got %d" % [effect_id, int(effect_definition.max_stacks)])
        _validate_required_target_effects(content_index, errors, effect_id, effect_definition)
        payload_validator.validate_effect_refs(errors, "effect[%s].on_expire_effect_ids" % effect_id, effect_definition.on_expire_effect_ids, content_index.effects)
        for payload in effect_definition.payloads:
            payload_validator.validate_payload(errors, effect_id, payload, content_index)

func _validate_required_target_effects(content_index, errors: Array, effect_id: String, effect_definition) -> void:
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
        if not content_index.effects.has(normalized_effect_id):
            errors.append("effect[%s].required_target_effects missing effect: %s" % [effect_id, normalized_effect_id])
