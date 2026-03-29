extends RefCounted
class_name ContentSnapshotTriggerContractValidator

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ApplyFieldPayloadScript := preload("res://src/battle_core/content/apply_field_payload.gd")

var _content_index = null

func validate(content_index, errors: Array) -> void:
    _content_index = content_index
    var allowed_triggers := PackedStringArray([
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
        "field_apply",
        ContentSchemaScript.TRIGGER_FIELD_APPLY_SUCCESS,
        "field_break",
        "field_expire",
        "on_expire",
    ])

    for skill_id in _content_index.skills.keys():
        var skill_definition = _content_index.skills[skill_id]
        _validate_effect_refs_require_trigger(errors, "skill[%s].effects_on_cast_ids" % skill_id, skill_definition.effects_on_cast_ids, PackedStringArray(["on_cast"]))
        _validate_effect_refs_require_trigger(errors, "skill[%s].effects_on_hit_ids" % skill_id, skill_definition.effects_on_hit_ids, PackedStringArray(["on_hit"]))
        _validate_effect_refs_require_trigger(errors, "skill[%s].effects_on_miss_ids" % skill_id, skill_definition.effects_on_miss_ids, PackedStringArray(["on_miss"]))
        _validate_effect_refs_require_trigger(errors, "skill[%s].effects_on_kill_ids" % skill_id, skill_definition.effects_on_kill_ids, PackedStringArray(["on_kill"]))

    for passive_id in _content_index.passive_skills.keys():
        var passive_definition = _content_index.passive_skills[passive_id]
        for trigger_name in passive_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("passive_skill[%s].trigger_names invalid: %s" % [passive_id, trigger_name])
        _validate_effect_refs_require_trigger(errors, "passive_skill[%s].effect_ids" % passive_id, passive_definition.effect_ids, passive_definition.trigger_names)

    for passive_id in _content_index.passive_items.keys():
        var passive_definition = _content_index.passive_items[passive_id]
        for trigger_name in passive_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("passive_item[%s].trigger_names invalid: %s" % [passive_id, trigger_name])
        _validate_effect_refs_require_trigger(errors, "passive_item[%s].effect_ids" % passive_id, passive_definition.effect_ids, passive_definition.trigger_names)
        _validate_effect_refs_require_trigger(errors, "passive_item[%s].always_on_effect_ids" % passive_id, passive_definition.always_on_effect_ids, PackedStringArray(["battle_init", "on_enter"]))
        _validate_effect_refs_require_trigger(errors, "passive_item[%s].on_turn_effect_ids" % passive_id, passive_definition.on_turn_effect_ids, PackedStringArray(["turn_start", "turn_end"]))

    for field_id in _content_index.fields.keys():
        var field_definition = _content_index.fields[field_id]
        _validate_effect_refs_require_trigger(errors, "field[%s].effect_ids" % field_id, field_definition.effect_ids, PackedStringArray(["field_apply"]))
        _validate_effect_refs_require_trigger(errors, "field[%s].on_expire_effect_ids" % field_id, field_definition.on_expire_effect_ids, PackedStringArray(["field_expire"]))
        _validate_effect_refs_require_trigger(errors, "field[%s].on_break_effect_ids" % field_id, field_definition.on_break_effect_ids, PackedStringArray(["field_break"]))

    for effect_id in _content_index.effects.keys():
        var effect_definition = _content_index.effects[effect_id]
        for trigger_name in effect_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("effect[%s].trigger_names invalid: %s" % [effect_id, trigger_name])
        _validate_effect_refs_require_trigger(errors, "effect[%s].on_expire_effect_ids" % effect_id, effect_definition.on_expire_effect_ids, PackedStringArray(["on_expire"]))
        _validate_apply_field_success_effects(errors, effect_id, effect_definition)

    _content_index = null

func _validate_effect_refs_require_trigger(errors: Array, label: String, effect_ids: PackedStringArray, required_triggers: PackedStringArray) -> void:
    if effect_ids.is_empty() or required_triggers.is_empty():
        return
    for effect_id in effect_ids:
        var effect_definition = _content_index.effects.get(String(effect_id))
        if effect_definition == null:
            continue
        for required_trigger in required_triggers:
            if effect_definition.trigger_names.has(required_trigger):
                continue
            errors.append("%s effect[%s] must declare trigger_names including %s" % [label, String(effect_id), String(required_trigger)])

func _validate_apply_field_success_effects(errors: Array, effect_id: String, effect_definition) -> void:
    for payload in effect_definition.payloads:
        if not payload is ApplyFieldPayloadScript:
            continue
        _validate_effect_refs_require_trigger(
            errors,
            "effect[%s].apply_field.on_success_effect_ids" % effect_id,
            payload.on_success_effect_ids,
            PackedStringArray([ContentSchemaScript.TRIGGER_FIELD_APPLY_SUCCESS])
        )
