extends RefCounted
class_name RuleModService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const RuleModInstanceScript := preload("res://src/battle_core/runtime/rule_mod_instance.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

const OWNER_SCOPE_UNIT := "unit"
const OWNER_SCOPE_FIELD := "field"
const FIELD_OWNER_ID := "field"

var id_factory
var last_error_code: Variant = null

func create_instance(rule_mod_payload, owner_ref: Dictionary, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int):
    last_error_code = null
    if not _validate_rule_mod_payload(rule_mod_payload):
        return null
    if not _validate_owner_ref(owner_ref, rule_mod_payload.scope, battle_state):
        return null
    var owner_instances: Array = _get_owner_instances(battle_state, owner_ref)
    var existing_instance = _find_existing(owner_instances, rule_mod_payload)
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
    rule_mod_instance.value = rule_mod_payload.value
    rule_mod_instance.scope = rule_mod_payload.scope
    rule_mod_instance.duration_mode = rule_mod_payload.duration_mode
    rule_mod_instance.owner_scope = owner_ref["scope"]
    rule_mod_instance.owner_id = owner_ref["id"]
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

func get_final_multiplier(battle_state, owner_id: String) -> float:
    if battle_state.get_unit(owner_id) == null:
        return 1.0
    var final_multiplier: float = 1.0
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_FINAL_MOD:
            continue
        match rule_mod_instance.mod_op:
            "mul":
                final_multiplier *= float(rule_mod_instance.value)
            "add":
                final_multiplier += float(rule_mod_instance.value)
            "set":
                final_multiplier = float(rule_mod_instance.value)
    return final_multiplier

func resolve_mp_regen_value(battle_state, owner_id: String, base_regen: int) -> int:
    if battle_state.get_unit(owner_id) == null:
        return max(0, base_regen)
    var regen_value: int = base_regen
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_MP_REGEN:
            continue
        match rule_mod_instance.mod_op:
            "add":
                regen_value += int(rule_mod_instance.value)
            "set":
                regen_value = int(rule_mod_instance.value)
    return max(0, regen_value)

func is_skill_allowed(battle_state, owner_id: String, skill_id: String) -> bool:
    if battle_state.get_unit(owner_id) == null:
        return false
    var allowed: bool = true
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_SKILL_LEGALITY:
            continue
        var affects_current_skill: bool = true
        if typeof(rule_mod_instance.value) == TYPE_STRING and not String(rule_mod_instance.value).is_empty():
            affects_current_skill = String(rule_mod_instance.value) == skill_id
        if not affects_current_skill:
            continue
        match rule_mod_instance.mod_op:
            "deny":
                allowed = false
            "allow":
                allowed = true
    return allowed

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

func _sorted_active_instances_for_read(battle_state, owner_id: String) -> Array:
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        return []
    var ordered_instances: Array = []
    for rule_mod_instance in owner_unit.rule_mod_instances:
        if rule_mod_instance.duration_mode == "turns" and rule_mod_instance.remaining <= 0:
            continue
        ordered_instances.append(rule_mod_instance)
    for rule_mod_instance in battle_state.field_rule_mod_instances:
        if rule_mod_instance.duration_mode == "turns" and rule_mod_instance.remaining <= 0:
            continue
        ordered_instances.append(rule_mod_instance)
    ordered_instances.sort_custom(_sort_rule_mods)
    return ordered_instances

func _find_existing(owner_instances: Array, rule_mod_payload):
    for rule_mod_instance in owner_instances:
        if rule_mod_instance.mod_kind == rule_mod_payload.mod_kind \
        and rule_mod_instance.mod_op == rule_mod_payload.mod_op \
        and rule_mod_instance.scope == rule_mod_payload.scope:
            return rule_mod_instance
    return null

func _validate_rule_mod_payload(rule_mod_payload) -> bool:
    var allowed_mod_kinds: PackedStringArray = PackedStringArray([
        ContentSchemaScript.RULE_MOD_FINAL_MOD,
        ContentSchemaScript.RULE_MOD_MP_REGEN,
        ContentSchemaScript.RULE_MOD_SKILL_LEGALITY,
    ])
    if not allowed_mod_kinds.has(rule_mod_payload.mod_kind):
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return false
    var allowed_scopes: PackedStringArray = PackedStringArray(["self", "target", "field"])
    if not allowed_scopes.has(rule_mod_payload.scope):
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return false
    var allowed_stacking: PackedStringArray = PackedStringArray([
        ContentSchemaScript.STACKING_NONE,
        ContentSchemaScript.STACKING_REFRESH,
        ContentSchemaScript.STACKING_REPLACE,
    ])
    if not allowed_stacking.has(rule_mod_payload.stacking):
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return false
    if rule_mod_payload.decrement_on != "turn_start" and rule_mod_payload.decrement_on != "turn_end":
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return false
    if rule_mod_payload.duration_mode != ContentSchemaScript.DURATION_TURNS and rule_mod_payload.duration_mode != ContentSchemaScript.DURATION_PERMANENT:
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return false
    if rule_mod_payload.duration_mode == "turns" and int(rule_mod_payload.duration) <= 0:
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return false
    if rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_FINAL_MOD:
        if rule_mod_payload.mod_op != "mul" and rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return false
    elif rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_MP_REGEN:
        if rule_mod_payload.mod_op != "add" and rule_mod_payload.mod_op != "set":
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return false
    elif rule_mod_payload.mod_kind == ContentSchemaScript.RULE_MOD_SKILL_LEGALITY:
        if rule_mod_payload.mod_op != "allow" and rule_mod_payload.mod_op != "deny":
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return false
    return true

func _validate_owner_ref(owner_ref: Dictionary, payload_scope: String, battle_state) -> bool:
    if owner_ref == null or not owner_ref.has("scope") or not owner_ref.has("id"):
        last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
        return false
    var owner_scope: String = str(owner_ref["scope"])
    var owner_id: String = str(owner_ref["id"])
    if owner_scope == OWNER_SCOPE_UNIT:
        if payload_scope == "field":
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return false
        if battle_state.get_unit(owner_id) == null:
            last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
            return false
        return true
    if owner_scope == OWNER_SCOPE_FIELD:
        if payload_scope != "field" or owner_id != FIELD_OWNER_ID:
            last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
            return false
        return true
    last_error_code = ErrorCodesScript.INVALID_RULE_MOD_DEFINITION
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

func _sort_rule_mods(left, right) -> bool:
    if left.priority != right.priority:
        return left.priority > right.priority
    if left.source_order_speed_snapshot != right.source_order_speed_snapshot:
        return left.source_order_speed_snapshot > right.source_order_speed_snapshot
    if left.source_kind_order != right.source_kind_order:
        return left.source_kind_order < right.source_kind_order
    if left.source_instance_id != right.source_instance_id:
        return left.source_instance_id < right.source_instance_id
    return left.instance_id < right.instance_id
