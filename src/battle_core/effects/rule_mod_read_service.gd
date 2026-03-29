extends RefCounted
class_name RuleModReadService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

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
    return is_action_allowed(battle_state, owner_id, "skill", skill_id)

func is_action_allowed(battle_state, owner_id: String, action_type: String, skill_id: String = "") -> bool:
    if battle_state.get_unit(owner_id) == null:
        return false
    if action_type == "wait" or action_type == "resource_forced_default" or action_type == "surrender":
        return true
    var allowed: bool = true
    var ordered_instances: Array = _sorted_active_instances_for_read(battle_state, owner_id)
    for rule_mod_instance in ordered_instances:
        if rule_mod_instance.mod_kind == ContentSchemaScript.RULE_MOD_ACTION_LEGALITY:
            if not _action_legality_matches(rule_mod_instance, action_type, skill_id):
                continue
        elif rule_mod_instance.mod_kind == ContentSchemaScript.RULE_MOD_SKILL_LEGALITY:
            if action_type != "skill" and action_type != "ultimate":
                continue
            if not _skill_legality_matches(rule_mod_instance, skill_id):
                continue
        else:
            continue
        allowed = rule_mod_instance.mod_op == "allow"
    return allowed

func resolve_incoming_accuracy(battle_state, owner_id: String, base_accuracy: int) -> int:
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
    match action_type:
        "skill":
            return value == ContentSchemaScript.ACTION_LEGALITY_ALL \
                or value == ContentSchemaScript.ACTION_LEGALITY_SKILL \
                or value == skill_id
        "ultimate":
            return value == ContentSchemaScript.ACTION_LEGALITY_ALL \
                or value == ContentSchemaScript.ACTION_LEGALITY_ULTIMATE \
                or value == skill_id
        "switch":
            return value == ContentSchemaScript.ACTION_LEGALITY_ALL \
                or value == ContentSchemaScript.ACTION_LEGALITY_SWITCH
        _:
            return false

func _skill_legality_matches(rule_mod_instance, skill_id: String) -> bool:
    if typeof(rule_mod_instance.value) != TYPE_STRING:
        return false
    var value := String(rule_mod_instance.value).strip_edges()
    return value.is_empty() or value == skill_id
