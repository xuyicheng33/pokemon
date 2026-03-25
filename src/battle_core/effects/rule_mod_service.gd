extends RefCounted
class_name RuleModService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const RuleModInstanceScript := preload("res://src/battle_core/runtime/rule_mod_instance.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var id_factory
var last_error_code: Variant = null

func create_instance(rule_mod_payload, owner_id: String, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int):
    last_error_code = null
    if not _validate_rule_mod_payload(rule_mod_payload):
        return null
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        last_error_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return null
    var existing_instance = _find_existing(owner_unit, rule_mod_payload)
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
                owner_unit.rule_mod_instances.erase(existing_instance)
    var rule_mod_instance = RuleModInstanceScript.new()
    rule_mod_instance.instance_id = id_factory.next_id("rule_mod")
    rule_mod_instance.mod_kind = rule_mod_payload.mod_kind
    rule_mod_instance.mod_op = rule_mod_payload.mod_op
    rule_mod_instance.value = rule_mod_payload.value
    rule_mod_instance.scope = rule_mod_payload.scope
    rule_mod_instance.duration_mode = rule_mod_payload.duration_mode
    rule_mod_instance.owner = owner_id
    rule_mod_instance.remaining = rule_mod_payload.duration if rule_mod_payload.duration_mode == "turns" else -1
    rule_mod_instance.created_turn = battle_state.turn_index
    rule_mod_instance.decrement_on = rule_mod_payload.decrement_on
    rule_mod_instance.source_instance_id = source_instance_id
    rule_mod_instance.source_kind_order = source_kind_order
    rule_mod_instance.source_order_speed_snapshot = source_order_speed_snapshot
    rule_mod_instance.priority = rule_mod_payload.priority
    owner_unit.rule_mod_instances.append(rule_mod_instance)
    return rule_mod_instance

func get_final_multiplier(battle_state, owner_id: String) -> float:
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        return 1.0
    var final_multiplier: float = 1.0
    var ordered_instances: Array = _sorted_active_instances(owner_unit)
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
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        return max(0, base_regen)
    var regen_value: int = base_regen
    var ordered_instances: Array = _sorted_active_instances(owner_unit)
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
    var owner_unit = battle_state.get_unit(owner_id)
    if owner_unit == null:
        return false
    var allowed: bool = true
    var ordered_instances: Array = _sorted_active_instances(owner_unit)
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
            var keep_instances: Array = []
            for rule_mod_instance in unit_state.rule_mod_instances:
                var should_remove: bool = false
                if rule_mod_instance.duration_mode == "turns" and rule_mod_instance.decrement_on == trigger_name:
                    rule_mod_instance.remaining -= 1
                    if rule_mod_instance.remaining <= 0:
                        should_remove = true
                if should_remove:
                    removed_instances.append({
                        "owner_id": unit_state.unit_instance_id,
                        "instance": rule_mod_instance,
                    })
                else:
                    keep_instances.append(rule_mod_instance)
            unit_state.rule_mod_instances = keep_instances
    return removed_instances

func _sorted_active_instances(owner_unit) -> Array:
    var ordered_instances: Array = []
    for rule_mod_instance in owner_unit.rule_mod_instances:
        if rule_mod_instance.duration_mode == "turns" and rule_mod_instance.remaining <= 0:
            continue
        ordered_instances.append(rule_mod_instance)
    ordered_instances.sort_custom(_sort_rule_mods)
    return ordered_instances

func _find_existing(owner_unit, rule_mod_payload):
    for rule_mod_instance in owner_unit.rule_mod_instances:
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
    if rule_mod_payload.decrement_on != "turn_start" and rule_mod_payload.decrement_on != "turn_end":
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
