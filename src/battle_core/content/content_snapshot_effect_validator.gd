extends RefCounted
class_name ContentSnapshotEffectValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const DamagePayloadScript := preload("res://src/battle_core/content/damage_payload.gd")
const HealPayloadScript := preload("res://src/battle_core/content/heal_payload.gd")
const ResourceModPayloadScript := preload("res://src/battle_core/content/resource_mod_payload.gd")
const StatModPayloadScript := preload("res://src/battle_core/content/stat_mod_payload.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")
const ApplyEffectPayloadScript := preload("res://src/battle_core/content/apply_effect_payload.gd")
const RemoveEffectPayloadScript := preload("res://src/battle_core/content/remove_effect_payload.gd")
const RuleModPayloadScript := preload("res://src/battle_core/content/rule_mod_payload.gd")

func validate(content_index, errors: Array, payload_validator) -> void:
    var allowed_scopes := PackedStringArray(["self", "target", "field", "action_actor"])
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
        _validate_action_actor_scope_contract(errors, effect_id, effect_definition)
        _validate_required_target_effects(content_index, errors, effect_id, effect_definition)
        _validate_incoming_action_filters(content_index, errors, effect_id, effect_definition)
        _validate_persistent_rule_mod_contract(errors, effect_id, effect_definition)
        payload_validator.validate_effect_refs(errors, "effect[%s].on_expire_effect_ids" % effect_id, effect_definition.on_expire_effect_ids, content_index.effects)
        for payload in effect_definition.payloads:
            payload_validator.validate_payload(errors, effect_id, payload, content_index)
            _validate_payload_scope_contract(errors, effect_id, effect_definition, payload)

func _validate_action_actor_scope_contract(errors: Array, effect_id: String, effect_definition) -> void:
    if String(effect_definition.scope) != "action_actor":
        return
    if effect_definition.trigger_names.is_empty():
        errors.append("effect[%s].scope action_actor only allowed for on_receive_action_hit" % effect_id)
        return
    for trigger_name in effect_definition.trigger_names:
        if String(trigger_name) != ContentSchemaScript.TRIGGER_ON_RECEIVE_ACTION_HIT:
            errors.append("effect[%s].scope action_actor only allowed for on_receive_action_hit" % effect_id)
            return

func _validate_payload_scope_contract(errors: Array, effect_id: String, effect_definition, payload) -> void:
    if payload == null:
        return
    if payload is ApplyFieldPayloadScript:
        if String(effect_definition.scope) != "field":
            errors.append("effect[%s].apply_field requires scope=field" % effect_id)
        return
    if _uses_effect_scope_unit_target(payload) and String(effect_definition.scope) == "field":
        errors.append(
            "effect[%s].%s requires scope=self/target/action_actor" % [
                effect_id,
                _resolve_payload_scope_label(payload),
            ]
        )

func _uses_effect_scope_unit_target(payload) -> bool:
    return payload is DamagePayloadScript \
        or payload is HealPayloadScript \
        or payload is ResourceModPayloadScript \
        or payload is StatModPayloadScript \
        or payload is ApplyEffectPayloadScript \
        or payload is RemoveEffectPayloadScript

func _resolve_payload_scope_label(payload) -> String:
    if payload is DamagePayloadScript:
        return "damage"
    if payload is HealPayloadScript:
        return "heal"
    if payload is ResourceModPayloadScript:
        return "resource_mod"
    if payload is StatModPayloadScript:
        return "stat_mod"
    if payload is ApplyFieldPayloadScript:
        return "apply_field"
    if payload is ApplyEffectPayloadScript:
        return "apply_effect"
    if payload is RemoveEffectPayloadScript:
        return "remove_effect"
    if payload is RuleModPayloadScript:
        return "rule_mod"
    return String(payload.payload_type if payload != null else "payload")

func _validate_required_target_effects(content_index, errors: Array, effect_id: String, effect_definition) -> void:
    if effect_definition.required_target_effects.is_empty():
        if bool(effect_definition.required_target_same_owner):
            errors.append("effect[%s].required_target_same_owner requires required_target_effects" % effect_id)
        return
    if effect_definition.scope != "target":
        errors.append("effect[%s].required_target_effects requires scope=target" % effect_id)
    if bool(effect_definition.required_target_same_owner) and effect_definition.scope != "target":
        errors.append("effect[%s].required_target_same_owner requires scope=target" % effect_id)
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

func _validate_persistent_rule_mod_contract(errors: Array, effect_id: String, effect_definition) -> void:
    if not bool(effect_definition.persists_on_switch):
        return
    for payload in effect_definition.payloads:
        if not (payload is RuleModPayloadScript):
            continue
        if bool(payload.persists_on_switch):
            continue
        errors.append("effect[%s].rule_mod persists_on_switch must be true when effect persists_on_switch=true" % effect_id)

func _validate_incoming_action_filters(content_index, errors: Array, effect_id: String, effect_definition) -> void:
    var command_filters: PackedStringArray = effect_definition.required_incoming_command_types
    var combat_type_filters: PackedStringArray = effect_definition.required_incoming_combat_type_ids
    if command_filters.is_empty() and combat_type_filters.is_empty():
        return
    var supports_incoming_filters: bool = effect_definition.trigger_names.has(ContentSchemaScript.TRIGGER_ON_RECEIVE_ACTION_HIT) \
        or effect_definition.trigger_names.has(ContentSchemaScript.TRIGGER_ON_RECEIVE_ACTION_DAMAGE_SEGMENT)
    if not supports_incoming_filters:
        if not command_filters.is_empty():
            errors.append("effect[%s].required_incoming_command_types only allowed for on_receive_action_hit/on_receive_action_damage_segment" % effect_id)
        if not combat_type_filters.is_empty():
            errors.append("effect[%s].required_incoming_combat_type_ids only allowed for on_receive_action_hit/on_receive_action_damage_segment" % effect_id)
        return
    for command_type in command_filters:
        var normalized_command_type := String(command_type).strip_edges()
        if normalized_command_type.is_empty():
            errors.append("effect[%s].required_incoming_command_types must not contain empty entry" % effect_id)
            continue
        if normalized_command_type != ContentSchemaScript.ACTION_LEGALITY_SKILL \
        and normalized_command_type != ContentSchemaScript.ACTION_LEGALITY_ULTIMATE:
            errors.append("effect[%s].required_incoming_command_types invalid: %s" % [effect_id, normalized_command_type])
    for combat_type_id in combat_type_filters:
        var normalized_combat_type_id := String(combat_type_id).strip_edges()
        if normalized_combat_type_id.is_empty():
            errors.append("effect[%s].required_incoming_combat_type_ids must not contain empty entry" % effect_id)
            continue
        if content_index != null and not content_index.combat_types.has(normalized_combat_type_id):
            errors.append("effect[%s].required_incoming_combat_type_ids missing combat type: %s" % [effect_id, normalized_combat_type_id])
