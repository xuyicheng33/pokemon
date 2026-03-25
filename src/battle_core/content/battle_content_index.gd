extends RefCounted
class_name BattleContentIndex

const BattleFormatConfigScript := preload("res://src/battle_core/content/battle_format_config.gd")
const UnitDefinitionScript := preload("res://src/battle_core/content/unit_definition.gd")
const SkillDefinitionScript := preload("res://src/battle_core/content/skill_definition.gd")
const PassiveSkillDefinitionScript := preload("res://src/battle_core/content/passive_skill_definition.gd")
const PassiveItemDefinitionScript := preload("res://src/battle_core/content/passive_item_definition.gd")
const EffectDefinitionScript := preload("res://src/battle_core/content/effect_definition.gd")
const FieldDefinitionScript := preload("res://src/battle_core/content/field_definition.gd")
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

var battle_formats: Dictionary = {}
var units: Dictionary = {}
var skills: Dictionary = {}
var passive_skills: Dictionary = {}
var passive_items: Dictionary = {}
var effects: Dictionary = {}
var fields: Dictionary = {}

func clear() -> void:
    battle_formats.clear()
    units.clear()
    skills.clear()
    passive_skills.clear()
    passive_items.clear()
    effects.clear()
    fields.clear()

func load_snapshot(content_snapshot_paths: PackedStringArray) -> void:
    clear()
    for path in content_snapshot_paths:
        var resource = ResourceLoader.load(path, "", 0)
        assert(resource != null, "Missing content resource: %s" % path)
        register_resource(resource)
    var errors = validate_snapshot()
    assert(errors.is_empty(), "Content validation failed:\n%s" % "\n".join(errors))

func register_resource(resource: Resource) -> void:
    if resource is BattleFormatConfigScript:
        battle_formats[resource.format_id] = resource
        return
    if resource is UnitDefinitionScript:
        units[resource.id] = resource
        return
    if resource is SkillDefinitionScript:
        skills[resource.id] = resource
        return
    if resource is PassiveSkillDefinitionScript:
        passive_skills[resource.id] = resource
        return
    if resource is PassiveItemDefinitionScript:
        passive_items[resource.id] = resource
        return
    if resource is EffectDefinitionScript:
        effects[resource.id] = resource
        return
    if resource is FieldDefinitionScript:
        fields[resource.id] = resource
        return
    assert(false, "Unsupported content resource: %s" % resource.resource_path)

func validate_snapshot() -> Array:
    var errors: Array = []
    var allowed_targets: PackedStringArray = PackedStringArray([
        ContentSchemaScript.TARGET_ENEMY_ACTIVE,
        ContentSchemaScript.TARGET_SELF,
        ContentSchemaScript.TARGET_FIELD,
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
    ])
    var regular_skill_refs: Dictionary = {}
    var ultimate_skill_refs: Dictionary = {}

    for unit_id in units.keys():
        var unit_definition = units[unit_id]
        if unit_definition.skill_ids.size() != 3:
            errors.append("unit[%s].skill_ids must contain exactly 3 entries, got %d" % [unit_id, unit_definition.skill_ids.size()])
        for skill_id in unit_definition.skill_ids:
            regular_skill_refs[skill_id] = true
            if not skills.has(skill_id):
                errors.append("unit[%s].skill_ids missing skill: %s" % [unit_id, skill_id])
        if not unit_definition.ultimate_skill_id.is_empty():
            ultimate_skill_refs[unit_definition.ultimate_skill_id] = true
            if not skills.has(unit_definition.ultimate_skill_id):
                errors.append("unit[%s].ultimate_skill_id missing skill: %s" % [unit_id, unit_definition.ultimate_skill_id])
            if unit_definition.skill_ids.has(unit_definition.ultimate_skill_id):
                errors.append("unit[%s].ultimate_skill_id duplicated in skill_ids: %s" % [unit_id, unit_definition.ultimate_skill_id])
        if not unit_definition.passive_skill_id.is_empty() and not passive_skills.has(unit_definition.passive_skill_id):
            errors.append("unit[%s].passive_skill_id missing passive skill: %s" % [unit_id, unit_definition.passive_skill_id])
        if not unit_definition.passive_item_id.is_empty() and not passive_items.has(unit_definition.passive_item_id):
            errors.append("unit[%s].passive_item_id missing passive item: %s" % [unit_id, unit_definition.passive_item_id])

    for skill_id in skills.keys():
        var skill_definition = skills[skill_id]
        if not allowed_targets.has(skill_definition.targeting):
            errors.append("skill[%s].targeting invalid: %s" % [skill_id, skill_definition.targeting])
        if int(skill_definition.priority) < -5 or int(skill_definition.priority) > 5:
            errors.append("skill[%s].priority out of range: %d" % [skill_id, int(skill_definition.priority)])
        _validate_effect_refs(errors, "skill[%s].effects_on_cast_ids" % skill_id, skill_definition.effects_on_cast_ids)
        _validate_effect_refs(errors, "skill[%s].effects_on_hit_ids" % skill_id, skill_definition.effects_on_hit_ids)
        _validate_effect_refs(errors, "skill[%s].effects_on_miss_ids" % skill_id, skill_definition.effects_on_miss_ids)
        _validate_effect_refs(errors, "skill[%s].effects_on_kill_ids" % skill_id, skill_definition.effects_on_kill_ids)

    for skill_id in regular_skill_refs.keys():
        if not skills.has(skill_id):
            continue
        var skill_definition = skills[skill_id]
        if int(skill_definition.priority) < -2 or int(skill_definition.priority) > 2:
            errors.append("skill[%s] used in unit.skill_ids must have priority in -2..2, got %d" % [skill_id, int(skill_definition.priority)])

    for skill_id in ultimate_skill_refs.keys():
        if not skills.has(skill_id):
            continue
        var skill_definition = skills[skill_id]
        if int(skill_definition.priority) != 5 and int(skill_definition.priority) != -5:
            errors.append("skill[%s] used as ultimate must have priority +5 or -5, got %d" % [skill_id, int(skill_definition.priority)])
        if regular_skill_refs.has(skill_id):
            errors.append("skill[%s] used as ultimate must not appear in any unit.skill_ids" % skill_id)

    for passive_id in passive_skills.keys():
        var passive_definition = passive_skills[passive_id]
        for trigger_name in passive_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("passive_skill[%s].trigger_names invalid: %s" % [passive_id, trigger_name])
        _validate_effect_refs(errors, "passive_skill[%s].effect_ids" % passive_id, passive_definition.effect_ids)

    for passive_id in passive_items.keys():
        var passive_definition = passive_items[passive_id]
        for trigger_name in passive_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("passive_item[%s].trigger_names invalid: %s" % [passive_id, trigger_name])
        _validate_effect_refs(errors, "passive_item[%s].effect_ids" % passive_id, passive_definition.effect_ids)
        _validate_effect_refs(errors, "passive_item[%s].always_on_effect_ids" % passive_id, passive_definition.always_on_effect_ids)
        if not passive_definition.on_receive_effect_ids.is_empty():
            errors.append("passive_item[%s].on_receive_effect_ids is disabled in current baseline and must be empty" % passive_id)
        _validate_effect_refs(errors, "passive_item[%s].on_turn_effect_ids" % passive_id, passive_definition.on_turn_effect_ids)

    for field_id in fields.keys():
        var field_definition = fields[field_id]
        _validate_effect_refs(errors, "field[%s].effect_ids" % field_id, field_definition.effect_ids)

    for effect_id in effects.keys():
        var effect_definition = effects[effect_id]
        if not allowed_scopes.has(effect_definition.scope):
            errors.append("effect[%s].scope invalid: %s" % [effect_id, effect_definition.scope])
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
        and effect_definition.stacking != ContentSchemaScript.STACKING_REPLACE:
            errors.append("effect[%s].stacking invalid: %s" % [effect_id, effect_definition.stacking])
        for trigger_name in effect_definition.trigger_names:
            if not allowed_triggers.has(trigger_name):
                errors.append("effect[%s].trigger_names invalid: %s" % [effect_id, trigger_name])
        for payload in effect_definition.payloads:
            _validate_payload(errors, effect_id, payload)

    return errors

func validate_setup(battle_setup) -> Array:
    var errors: Array = []
    if battle_setup == null:
        errors.append("battle_setup missing")
        return errors
    for side_setup in battle_setup.sides:
        var side_id: String = str(side_setup.side_id)
        var seen_passive_items: Dictionary = {}
        for unit_definition_id in side_setup.unit_definition_ids:
            if not units.has(unit_definition_id):
                continue
            var unit_definition = units[unit_definition_id]
            var passive_item_id := str(unit_definition.passive_item_id)
            if passive_item_id.is_empty():
                continue
            if seen_passive_items.has(passive_item_id):
                errors.append("battle_setup.side[%s] duplicated passive_item_id: %s" % [side_id, passive_item_id])
                continue
            seen_passive_items[passive_item_id] = true
    return errors

func _validate_effect_refs(errors: Array, label: String, effect_ids: PackedStringArray) -> void:
    for effect_id in effect_ids:
        if not effects.has(effect_id):
            errors.append("%s missing effect: %s" % [label, effect_id])

func _validate_payload(errors: Array, effect_id: String, payload) -> void:
    if payload == null:
        errors.append("effect[%s].payloads contains null" % effect_id)
        return
    if payload is DamagePayloadScript:
        return
    if payload is HealPayloadScript:
        return
    if payload is ResourceModPayloadScript:
        return
    if payload is StatModPayloadScript:
        return
    if payload is ApplyFieldPayloadScript:
        if String(payload.field_definition_id).is_empty() or not fields.has(payload.field_definition_id):
            errors.append("effect[%s].apply_field missing field: %s" % [effect_id, payload.field_definition_id])
        return
    if payload is ApplyEffectPayloadScript:
        if String(payload.effect_definition_id).is_empty() or not effects.has(payload.effect_definition_id):
            errors.append("effect[%s].apply_effect missing effect: %s" % [effect_id, payload.effect_definition_id])
        return
    if payload is RemoveEffectPayloadScript:
        if String(payload.effect_definition_id).is_empty() or not effects.has(payload.effect_definition_id):
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
    return errors
