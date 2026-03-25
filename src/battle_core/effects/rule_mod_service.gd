extends RefCounted
class_name RuleModService

const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const RuleModInstanceScript := preload("res://src/battle_core/runtime/rule_mod_instance.gd")

var id_factory

func create_instance(rule_mod_payload, owner_id: String, battle_state, source_instance_id: String, source_kind_order: int, source_order_speed_snapshot: int):
    var owner_unit = battle_state.get_unit(owner_id)
    assert(owner_unit != null, "Rule mod owner missing: %s" % owner_id)
    var existing_instance = _find_existing(owner_unit, rule_mod_payload)
    match rule_mod_payload.stacking:
        ContentSchemaScript.STACKING_NONE:
            if existing_instance != null:
                return existing_instance
        ContentSchemaScript.STACKING_REFRESH:
            if existing_instance != null:
                existing_instance.remaining = rule_mod_payload.duration
                return existing_instance
        ContentSchemaScript.STACKING_REPLACE:
            if existing_instance != null:
                owner_unit.rule_mod_instances.erase(existing_instance)
    var rule_mod_instance = RuleModInstanceScript.new()
    rule_mod_instance.instance_id = id_factory.next_id("rule_mod")
    rule_mod_instance.mod_kind = rule_mod_payload.mod_kind
    rule_mod_instance.mod_op = rule_mod_payload.mod_op
    rule_mod_instance.value = rule_mod_payload.value
    rule_mod_instance.owner = owner_id
    rule_mod_instance.remaining = rule_mod_payload.duration
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
    var ordered_instances: Array = owner_unit.rule_mod_instances.duplicate()
    ordered_instances.sort_custom(_sort_rule_mods)
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

func _find_existing(owner_unit, rule_mod_payload):
    for rule_mod_instance in owner_unit.rule_mod_instances:
        if rule_mod_instance.mod_kind == rule_mod_payload.mod_kind \
        and rule_mod_instance.mod_op == rule_mod_payload.mod_op:
            return rule_mod_instance
    return null

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
