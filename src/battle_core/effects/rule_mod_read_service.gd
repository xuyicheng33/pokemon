extends RefCounted
class_name RuleModReadService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var last_error_code: Variant = null
var last_error_message: String = ""

func error_state() -> Dictionary:
    return {
        "code": last_error_code,
        "message": last_error_message,
    }

func get_final_multiplier(battle_state, owner_id: String) -> float:
    _reset_error_state()
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
    _reset_error_state()
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

func is_action_allowed(battle_state, owner_id: String, action_type: String, skill_id: String = "") -> bool:
    _reset_error_state()
    if battle_state.get_unit(owner_id) == null:
        return false
    if _is_always_allowed_action_type(action_type):
        return true
    if not _is_managed_action_type(action_type):
        _fail_unsupported_action_type(action_type)
        return false
    var allowed: bool = true
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_ACTION_LEGALITY:
            continue
        if not _action_legality_matches(rule_mod_instance, action_type, skill_id):
            if last_error_code != null:
                return false
            continue
        allowed = rule_mod_instance.mod_op == "allow"
    return allowed

func resolve_incoming_accuracy(battle_state, owner_id: String, base_accuracy: int) -> int:
    _reset_error_state()
    if battle_state.get_unit(owner_id) == null:
        return clamp(base_accuracy, 0, 99)
    var resolved_accuracy: int = base_accuracy
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_INCOMING_ACCURACY:
            continue
        match rule_mod_instance.mod_op:
            "add":
                resolved_accuracy += int(rule_mod_instance.value)
            "set":
                resolved_accuracy = int(rule_mod_instance.value)
    return clamp(resolved_accuracy, 0, 99)

func has_nullify_field_accuracy(battle_state, owner_id: String) -> bool:
    _reset_error_state()
    if battle_state.get_unit(owner_id) == null:
        return false
    var is_enabled := false
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_NULLIFY_FIELD_ACCURACY:
            continue
        if rule_mod_instance.mod_op == "set":
            is_enabled = bool(rule_mod_instance.value)
    return is_enabled

func resolve_incoming_action_final_multiplier(battle_state, owner_id: String, command_type: String, combat_type_id: String) -> float:
    _reset_error_state()
    if battle_state.get_unit(owner_id) == null:
        return 1.0
    var final_multiplier: float = 1.0
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind != ContentSchemaScript.RULE_MOD_INCOMING_ACTION_FINAL_MOD:
            continue
        if not _incoming_action_filters_match(rule_mod_instance, command_type, combat_type_id):
            continue
        match rule_mod_instance.mod_op:
            "mul":
                final_multiplier *= float(rule_mod_instance.value)
            "add":
                final_multiplier += float(rule_mod_instance.value)
            "set":
                final_multiplier = float(rule_mod_instance.value)
    return final_multiplier

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

func _action_legality_matches(rule_mod_instance, action_type: String, skill_id: String) -> bool:
    var value := String(rule_mod_instance.value).strip_edges()
    var match_tokens := _build_action_legality_match_tokens(action_type, skill_id)
    if last_error_code != null:
        return false
    return match_tokens.has(value)

func _build_action_legality_match_tokens(action_type: String, skill_id: String) -> PackedStringArray:
    if not _is_managed_action_type(action_type):
        _fail_unsupported_action_type(action_type)
        return PackedStringArray()
    var match_tokens := PackedStringArray()
    match String(action_type):
        ContentSchemaScript.ACTION_LEGALITY_SKILL:
            match_tokens = PackedStringArray([
                ContentSchemaScript.ACTION_LEGALITY_ALL,
                ContentSchemaScript.ACTION_LEGALITY_SKILL,
            ])
        ContentSchemaScript.ACTION_LEGALITY_ULTIMATE:
            match_tokens = PackedStringArray([
                ContentSchemaScript.ACTION_LEGALITY_ALL,
                ContentSchemaScript.ACTION_LEGALITY_ULTIMATE,
            ])
        ContentSchemaScript.ACTION_LEGALITY_SWITCH:
            match_tokens = PackedStringArray([
                ContentSchemaScript.ACTION_LEGALITY_ALL,
                ContentSchemaScript.ACTION_LEGALITY_SWITCH,
            ])
        _:
            _fail_unsupported_action_type(action_type)
            return PackedStringArray()
    if String(action_type) != ContentSchemaScript.ACTION_LEGALITY_SWITCH and not skill_id.is_empty():
        match_tokens.append(skill_id)
    return match_tokens

func _is_managed_action_type(action_type: String) -> bool:
    return ContentSchemaScript.MANAGED_ACTION_TYPES.has(String(action_type))

func _is_always_allowed_action_type(action_type: String) -> bool:
    return ContentSchemaScript.ALWAYS_ALLOWED_ACTION_TYPES.has(String(action_type))

func _reset_error_state() -> void:
    last_error_code = null
    last_error_message = ""

func _fail_unsupported_action_type(action_type: String) -> void:
    last_error_code = ErrorCodesScript.INVALID_COMMAND_PAYLOAD
    last_error_message = "unsupported action_legality action_type: %s" % String(action_type)

func _incoming_action_filters_match(rule_mod_instance, command_type: String, combat_type_id: String) -> bool:
    var command_filters: PackedStringArray = rule_mod_instance.required_incoming_command_types
    if not command_filters.is_empty() and not command_filters.has(command_type):
        return false
    var combat_type_filters: PackedStringArray = rule_mod_instance.required_incoming_combat_type_ids
    if not combat_type_filters.is_empty() and not combat_type_filters.has(combat_type_id):
        return false
    return true
