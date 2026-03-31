extends RefCounted
class_name RuleModWriteService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const RuleModSchemaScript := preload("res://src/battle_core/content/rule_mod_schema.gd")
const RuleModInstanceScript := preload("res://src/battle_core/runtime/rule_mod_instance.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

const OWNER_SCOPE_UNIT := "unit"
const OWNER_SCOPE_FIELD := "field"
const FIELD_OWNER_ID := "field"
const SKILL_LEGALITY_GLOBAL_KEY := "__all_skills__"
const STACKING_KEY_SCHEMA_BY_KIND := RuleModSchemaScript.STACKING_KEY_SCHEMA_BY_KIND

var id_factory
var last_error_code: Variant = null
var last_error_message: String = ""
var _rule_mod_schema = RuleModSchemaScript.new()

func create_instance(rule_mod_payload, owner_ref: Dictionary, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int, resolved_value = null):
    last_error_code = null
    last_error_message = ""
    if not _validate_rule_mod_payload(rule_mod_payload):
        return null
    if not _validate_owner_ref(owner_ref, rule_mod_payload.scope, battle_state):
        return null
    var owner_instances: Array = _get_owner_instances(battle_state, owner_ref)
    var stacking_key: String = _build_stacking_key(rule_mod_payload, owner_ref)
    if last_error_code != null:
        return null
    var existing_instance = _find_existing(owner_instances, stacking_key)
    match rule_mod_payload.stacking:
        ContentSchemaScript.STACKING_NONE:
            if existing_instance != null:
                return existing_instance
        ContentSchemaScript.STACKING_REFRESH:
            if existing_instance != null:
                existing_instance.remaining = rule_mod_payload.duration if rule_mod_payload.duration_mode == "turns" else -1
                return existing_instance
        ContentSchemaScript.STACKING_REPLACE:
            if existing_instance != null:
                owner_instances.erase(existing_instance)
    var rule_mod_instance = RuleModInstanceScript.new()
    rule_mod_instance.instance_id = id_factory.next_id("rule_mod")
    rule_mod_instance.mod_kind = rule_mod_payload.mod_kind
    rule_mod_instance.mod_op = rule_mod_payload.mod_op
    rule_mod_instance.value = resolved_value if resolved_value != null else rule_mod_payload.value
    rule_mod_instance.scope = rule_mod_payload.scope
    rule_mod_instance.duration_mode = rule_mod_payload.duration_mode
    rule_mod_instance.owner_scope = owner_ref["scope"]
    rule_mod_instance.owner_id = owner_ref["id"]
    rule_mod_instance.field_instance_id = _resolve_field_instance_id(owner_ref, battle_state)
    rule_mod_instance.stacking_key = stacking_key
    rule_mod_instance.remaining = rule_mod_payload.duration if rule_mod_payload.duration_mode == "turns" else -1
    rule_mod_instance.created_turn = battle_state.turn_index
    rule_mod_instance.decrement_on = rule_mod_payload.decrement_on
    rule_mod_instance.source_instance_id = source_instance_id
    rule_mod_instance.source_kind_order = source_kind_order
    rule_mod_instance.source_order_speed_snapshot = source_order_speed_snapshot
    rule_mod_instance.priority = rule_mod_payload.priority
    owner_instances.append(rule_mod_instance)
    _set_owner_instances(battle_state, owner_ref, owner_instances)
    return rule_mod_instance

func decrement_for_trigger(battle_state, trigger_name: String) -> Array:
    var removed_instances: Array = []
    for side_state in battle_state.sides:
        for unit_state in side_state.team_units:
            var unit_result: Dictionary = _decrement_owner_instances(unit_state.rule_mod_instances, unit_state.unit_instance_id, trigger_name)
            unit_state.rule_mod_instances = unit_result["keep_instances"]
            removed_instances.append_array(unit_result["removed_instances"])
    var field_result: Dictionary = _decrement_owner_instances(battle_state.field_rule_mod_instances, FIELD_OWNER_ID, trigger_name)
    battle_state.field_rule_mod_instances = field_result["keep_instances"]
    removed_instances.append_array(field_result["removed_instances"])
    return removed_instances

func _find_existing(owner_instances: Array, stacking_key: String):
    for rule_mod_instance in owner_instances:
        if rule_mod_instance.stacking_key == stacking_key:
            return rule_mod_instance
    return null

func _validate_rule_mod_payload(rule_mod_payload) -> bool:
    if _rule_mod_schema.validate_payload(rule_mod_payload).is_empty():
        return true
    last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
    last_error_message = "rule_mod payload failed schema validation"
    return false

func _validate_owner_ref(owner_ref: Dictionary, payload_scope: String, battle_state) -> bool:
    if owner_ref == null or not owner_ref.has("scope") or not owner_ref.has("id"):
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        last_error_message = "rule_mod owner_ref must include scope/id"
        return false
    var owner_scope: String = str(owner_ref["scope"])
    var owner_id: String = str(owner_ref["id"])
    if owner_scope == OWNER_SCOPE_UNIT:
        if payload_scope == "field":
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            last_error_message = "field-scope rule_mod requires field owner"
            return false
        if battle_state.get_unit(owner_id) == null:
            last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
            last_error_message = "rule_mod owner unit missing: %s" % owner_id
            return false
        return true
    if owner_scope == OWNER_SCOPE_FIELD:
        if payload_scope != "field" or owner_id != FIELD_OWNER_ID:
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            last_error_message = "field owner_ref must bind scope=field id=field"
            return false
        return true
    last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
    last_error_message = "unsupported rule_mod owner scope: %s" % owner_scope
    return false

func _get_owner_instances(battle_state, owner_ref: Dictionary) -> Array:
    var owner_scope: String = str(owner_ref["scope"])
    if owner_scope == OWNER_SCOPE_FIELD:
        return battle_state.field_rule_mod_instances
    var owner_unit = battle_state.get_unit(str(owner_ref["id"]))
    if owner_unit == null:
        return []
    return owner_unit.rule_mod_instances

func _set_owner_instances(battle_state, owner_ref: Dictionary, instances: Array) -> void:
    var owner_scope: String = str(owner_ref["scope"])
    if owner_scope == OWNER_SCOPE_FIELD:
        battle_state.field_rule_mod_instances = instances
        return
    var owner_unit = battle_state.get_unit(str(owner_ref["id"]))
    if owner_unit != null:
        owner_unit.rule_mod_instances = instances

func _decrement_owner_instances(owner_instances: Array, owner_id: String, trigger_name: String) -> Dictionary:
    var keep_instances: Array = []
    var removed_instances: Array = []
    for rule_mod_instance in owner_instances:
        var should_remove: bool = false
        if rule_mod_instance.duration_mode == "turns" and rule_mod_instance.decrement_on == trigger_name:
            rule_mod_instance.remaining -= 1
            if rule_mod_instance.remaining <= 0:
                should_remove = true
        if should_remove:
            removed_instances.append({
                "owner_id": owner_id,
                "instance": rule_mod_instance,
            })
        else:
            keep_instances.append(rule_mod_instance)
    return {
        "keep_instances": keep_instances,
        "removed_instances": removed_instances,
    }

func _resolve_field_instance_id(owner_ref: Dictionary, battle_state) -> String:
    if str(owner_ref.get("scope", "")) != OWNER_SCOPE_FIELD:
        return ""
    if battle_state == null or battle_state.field_state == null:
        return ""
    return str(battle_state.field_state.instance_id)

func _build_stacking_key(rule_mod_payload, owner_ref: Dictionary) -> String:
    var schema: Array = _resolve_stacking_key_schema(String(rule_mod_payload.mod_kind))
    if schema.is_empty():
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        last_error_message = "Missing stacking key schema for rule_mod kind: %s" % rule_mod_payload.mod_kind
        return ""
    var key_parts: PackedStringArray = PackedStringArray()
    for field_name in schema:
        match str(field_name):
            "mod_kind":
                key_parts.append(str(rule_mod_payload.mod_kind))
            "scope":
                key_parts.append(str(rule_mod_payload.scope))
            "owner_scope":
                key_parts.append(str(owner_ref["scope"]))
            "owner_id":
                key_parts.append(str(owner_ref["id"]))
            "mod_op":
                key_parts.append(str(rule_mod_payload.mod_op))
            "value":
                key_parts.append(_resolve_stacking_value_token(rule_mod_payload))
            _:
                last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
                last_error_message = "Unknown stacking key field: %s" % str(field_name)
                return ""
    return "|".join(key_parts)

func _resolve_stacking_key_schema(mod_kind: String) -> Array:
    return STACKING_KEY_SCHEMA_BY_KIND.get(mod_kind, [])

func _resolve_stacking_value_token(rule_mod_payload) -> String:
    if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_SKILL_LEGALITY:
        if typeof(rule_mod_payload.value) == TYPE_STRING and not String(rule_mod_payload.value).is_empty():
            return "skill:%s" % String(rule_mod_payload.value)
        return SKILL_LEGALITY_GLOBAL_KEY
    if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_ACTION_LEGALITY:
        var action_value := String(rule_mod_payload.value).strip_edges()
        if action_value == ContentSchemaScript.ACTION_LEGALITY_ALL \
        or action_value == ContentSchemaScript.ACTION_LEGALITY_SKILL \
        or action_value == ContentSchemaScript.ACTION_LEGALITY_ULTIMATE \
        or action_value == ContentSchemaScript.ACTION_LEGALITY_SWITCH:
            return "action:%s" % action_value
        return "skill:%s" % action_value
    return str(rule_mod_payload.value)
