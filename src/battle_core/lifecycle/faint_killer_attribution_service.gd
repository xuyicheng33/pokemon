extends RefCounted
class_name FaintKillerAttributionService

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

const SOURCE_KIND_ORDER_ACTIVE_SKILL := 2

var trigger_dispatcher

func resolve_missing_dependency() -> String:
    if trigger_dispatcher == null:
        return "trigger_dispatcher"
    return ""

func record_fatal_damage(
    battle_state,
    target_unit_id: String,
    before_hp: int,
    after_hp: int,
    killer_unit_id: Variant,
    source_instance_id: String,
    source_kind_order: int,
    source_order_speed_snapshot: int,
    priority: int,
    cause_event_step_id: int
) -> void:
    if before_hp <= 0 or after_hp > 0:
        return
    var record_index: int = 0
    if battle_state.fatal_damage_records_by_target.has(target_unit_id):
        record_index = battle_state.fatal_damage_records_by_target[target_unit_id].size()
    var fatal_record = {
        "target_unit_id": target_unit_id,
        "killer_id": str(killer_unit_id) if killer_unit_id != null else null,
        "source_instance_id": source_instance_id,
        "source_kind_order": source_kind_order,
        "source_order_speed_snapshot": source_order_speed_snapshot,
        "priority": priority,
        "cause_event_step_id": cause_event_step_id,
        "record_index": record_index,
    }
    if not battle_state.fatal_damage_records_by_target.has(target_unit_id):
        battle_state.fatal_damage_records_by_target[target_unit_id] = []
    battle_state.fatal_damage_records_by_target[target_unit_id].append(fatal_record)

func resolve_killer_units(battle_state, fainted_unit_ids: Array) -> Dictionary:
    var killer_unit_ids: Array = []
    for fainted_unit_id in fainted_unit_ids:
        var killer_id = resolve_killer_for_target(battle_state, fainted_unit_id)
        if killer_id == null or killer_id == fainted_unit_id:
            continue
        if not killer_unit_ids.has(killer_id):
            killer_unit_ids.append(killer_id)
    killer_unit_ids.sort()
    return {"killer_unit_ids": killer_unit_ids}

func resolve_killer_for_target(battle_state, target_unit_id: String) -> Variant:
    if not battle_state.fatal_damage_records_by_target.has(target_unit_id):
        return null
    var records: Array = battle_state.fatal_damage_records_by_target[target_unit_id]
    if records.is_empty():
        return null
    var latest_step_id: int = -1
    for record in records:
        latest_step_id = max(latest_step_id, int(record.get("cause_event_step_id", -1)))
    var tied_records: Array = []
    for record in records:
        if int(record.get("cause_event_step_id", -1)) == latest_step_id:
            tied_records.append(record)
    if tied_records.is_empty():
        return null
    tied_records.sort_custom(_sort_killer_records)
    var killer_id = tied_records[0].get("killer_id", null)
    if killer_id == null:
        return null
    var killer_id_string := str(killer_id)
    if killer_id_string.is_empty():
        return null
    return killer_id_string

func collect_action_on_kill_events(battle_state, content_index, killer_unit_ids: Array) -> Dictionary:
    if killer_unit_ids.is_empty():
        return {"events": [], "invalid_code": null}
    if battle_state.chain_context == null or battle_state.chain_context.chain_origin != "action":
        return {"events": [], "invalid_code": null}
    var actor_id = battle_state.chain_context.actor_id
    if actor_id == null:
        return {"events": [], "invalid_code": null}
    var actor_unit_id := str(actor_id)
    if not killer_unit_ids.has(actor_unit_id):
        return {"events": [], "invalid_code": null}
    var command_type = battle_state.chain_context.command_type
    if command_type != CommandTypesScript.SKILL and command_type != CommandTypesScript.ULTIMATE:
        return {"events": [], "invalid_code": null}
    var skill_id: String = str(battle_state.chain_context.skill_id) if battle_state.chain_context.skill_id != null else ""
    if skill_id.is_empty():
        return {"events": [], "invalid_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
    var skill_definition = content_index.skills.get(skill_id)
    if skill_definition == null:
        return {"events": [], "invalid_code": ErrorCodesScript.INVALID_EFFECT_DEFINITION}
    if skill_definition.effects_on_kill_ids.is_empty():
        return {"events": [], "invalid_code": null}
    var actor_unit = battle_state.get_unit(actor_unit_id)
    if actor_unit == null:
        return {"events": [], "invalid_code": ErrorCodesScript.INVALID_STATE_CORRUPTION}
    var source_speed_snapshot: int = actor_unit.last_effective_speed if actor_unit.last_effective_speed > 0 else actor_unit.base_speed
    var source_instance_id: String = str(battle_state.chain_context.root_action_id) if battle_state.chain_context.root_action_id != null else battle_state.chain_context.event_chain_id
    var effect_events: Array = trigger_dispatcher.collect_events(
        "on_kill",
        battle_state,
        content_index,
        skill_definition.effects_on_kill_ids,
        actor_unit_id,
        source_instance_id,
        SOURCE_KIND_ORDER_ACTIVE_SKILL,
        source_speed_snapshot,
        battle_state.chain_context
    )
    return {"events": effect_events, "invalid_code": null}

func clear_fatal_damage_records(battle_state, fainted_unit_ids: Array) -> void:
    for fainted_unit_id in fainted_unit_ids:
        battle_state.fatal_damage_records_by_target.erase(fainted_unit_id)

func _sort_killer_records(left: Dictionary, right: Dictionary) -> bool:
    if int(left.get("priority", 0)) != int(right.get("priority", 0)):
        return int(left.get("priority", 0)) > int(right.get("priority", 0))
    if int(left.get("source_order_speed_snapshot", 0)) != int(right.get("source_order_speed_snapshot", 0)):
        return int(left.get("source_order_speed_snapshot", 0)) > int(right.get("source_order_speed_snapshot", 0))
    if int(left.get("source_kind_order", 0)) != int(right.get("source_kind_order", 0)):
        return int(left.get("source_kind_order", 0)) < int(right.get("source_kind_order", 0))
    if str(left.get("source_instance_id", "")) != str(right.get("source_instance_id", "")):
        return str(left.get("source_instance_id", "")) < str(right.get("source_instance_id", ""))
    if str(left.get("killer_id", "")) != str(right.get("killer_id", "")):
        return str(left.get("killer_id", "")) < str(right.get("killer_id", ""))
    return int(left.get("record_index", 0)) < int(right.get("record_index", 0))
