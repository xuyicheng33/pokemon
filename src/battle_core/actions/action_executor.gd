extends RefCounted
class_name ActionExecutor

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const LeaveStatesScript := preload("res://src/shared/leave_states.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")
const ActionResultScript := preload("res://src/battle_core/contracts/action_result.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const ValueChangeScript := preload("res://src/battle_core/contracts/value_change.gd")

var mp_service
var hit_service
var damage_service
var stat_calculator
var rule_mod_service
var leave_service
var target_resolver
var trigger_dispatcher
var effect_queue_service
var payload_executor
var battle_logger
var log_event_builder
var rng_service

func execute_action(queued_action, battle_state, content_index):
    var result = ActionResultScript.new()
    result.action_id = queued_action.action_id
    var command = queued_action.command
    var actor = battle_state.get_unit(command.actor_id)
    battle_state.chain_context = _build_chain_context(queued_action, battle_state)
    if not _can_start_action(actor, command, battle_state):
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.ACTION_CANCELLED_PRE_START,
            battle_state,
            {
                "source_instance_id": queued_action.action_id,
                "target_instance_id": command.actor_id,
                "priority": queued_action.priority,
                "speed_tie_roll": queued_action.speed_tie_roll,
                "payload_summary": "%s cancelled before start" % command.command_type,
            }
        ))
        result.result_type = "cancelled_pre_start"
        return result
    actor.action_window_passed = true
    actor.has_acted = true
    var skill_definition = null
    if command.command_type == CommandTypesScript.SKILL or command.command_type == CommandTypesScript.ULTIMATE:
        skill_definition = content_index.skills.get(command.skill_id)
        assert(skill_definition != null, "Missing skill definition: %s" % command.skill_id)
    var consumed_mp: int = _resolve_mp_cost(command, skill_definition)
    var mp_changes: Array = []
    if consumed_mp > 0:
        var before_mp: int = actor.current_mp
        actor.current_mp = mp_service.consume_mp(actor.current_mp, consumed_mp)
        mp_changes.append(_build_value_change(actor.unit_instance_id, "mp", before_mp, actor.current_mp))
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.ACTION_CAST,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": queued_action.target_snapshot.target_unit_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "action_window_passed": actor.action_window_passed,
            "has_acted": actor.has_acted,
            "speed_tie_roll": queued_action.speed_tie_roll,
            "value_changes": mp_changes,
            "payload_summary": "%s cast" % command.command_type,
        }
    ))
    result.consumed_mp = consumed_mp
    _dispatch_skill_effects(skill_definition.effects_on_cast_ids if skill_definition != null else PackedStringArray(), "on_cast", queued_action, actor, battle_state, content_index, result)
    if command.command_type == CommandTypesScript.SWITCH:
        var switch_result = _execute_switch_action(queued_action, battle_state)
        switch_result.action_id = queued_action.action_id
        return switch_result
    var resolved_target = target_resolver.resolve_target(queued_action, battle_state)
    if resolved_target != null and queued_action.target_snapshot.target_kind != ContentSchemaScript.TARGET_FIELD:
        battle_state.chain_context.target_unit_id = resolved_target.unit_instance_id
    if not _is_action_target_valid(command, queued_action, resolved_target):
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.ACTION_FAILED_POST_START,
            battle_state,
            {
                "source_instance_id": queued_action.action_id,
                "priority": queued_action.priority,
                "target_slot": queued_action.target_snapshot.target_slot,
                "action_window_passed": actor.action_window_passed,
                "has_acted": actor.has_acted,
                "speed_tie_roll": queued_action.speed_tie_roll,
                "payload_summary": "%s failed at execution start" % command.command_type,
            }
        ))
        result.result_type = "action_failed_post_start"
        return result
    var hit_info: Dictionary = _resolve_hit(command, skill_definition, battle_state)
    if not hit_info["hit"]:
        battle_logger.append_event(log_event_builder.build_event(
            EventTypesScript.ACTION_MISS,
            battle_state,
            {
                "source_instance_id": queued_action.action_id,
                "target_instance_id": _resolve_target_instance_id(queued_action, resolved_target),
                "priority": queued_action.priority,
                "target_slot": queued_action.target_snapshot.target_slot,
                "action_window_passed": actor.action_window_passed,
                "has_acted": actor.has_acted,
                "speed_tie_roll": queued_action.speed_tie_roll,
                "hit_roll": hit_info["hit_roll"],
                "payload_summary": "%s missed" % command.command_type,
            }
        ))
        _dispatch_skill_effects(skill_definition.effects_on_miss_ids if skill_definition != null else PackedStringArray(), "on_miss", queued_action, actor, battle_state, content_index, result)
        result.result_type = "miss"
        return result
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.ACTION_HIT,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": _resolve_target_instance_id(queued_action, resolved_target),
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "action_window_passed": actor.action_window_passed,
            "has_acted": actor.has_acted,
            "speed_tie_roll": queued_action.speed_tie_roll,
            "hit_roll": hit_info["hit_roll"],
            "payload_summary": "%s hit" % command.command_type,
        }
    ))
    if _is_damage_action(command, skill_definition):
        _apply_direct_damage(queued_action, actor, resolved_target, skill_definition, battle_state)
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT or command.command_type == CommandTypesScript.TIMEOUT_DEFAULT:
        _apply_default_recoil(queued_action, actor, battle_state)
    _dispatch_skill_effects(skill_definition.effects_on_hit_ids if skill_definition != null else PackedStringArray(), "on_hit", queued_action, actor, battle_state, content_index, result)
    result.result_type = "resolved"
    return result

func _build_chain_context(queued_action, battle_state):
    var chain_context = ChainContextScript.new()
    chain_context.event_chain_id = queued_action.action_id
    chain_context.root_action_id = queued_action.action_id
    chain_context.chain_origin = "action"
    chain_context.action_queue_index = queued_action.queue_index
    chain_context.actor_id = queued_action.command.actor_id
    chain_context.command_type = queued_action.command.command_type
    chain_context.command_source = queued_action.command.command_source
    chain_context.select_timeout = queued_action.command.command_type == CommandTypesScript.TIMEOUT_DEFAULT
    chain_context.select_deadline_ms = battle_state.selection_deadline_ms
    chain_context.target_unit_id = queued_action.target_snapshot.target_unit_id
    chain_context.target_slot = queued_action.target_snapshot.target_slot
    return chain_context

func _can_start_action(actor, command, battle_state) -> bool:
    if actor == null or actor.current_hp <= 0 or actor.leave_state != LeaveStatesScript.ACTIVE:
        return false
    var side_state = battle_state.get_side(command.side_id)
    return side_state != null and side_state.get_active_unit() != null and side_state.get_active_unit().unit_instance_id == actor.unit_instance_id

func _resolve_mp_cost(command, skill_definition) -> int:
    if command.command_type == CommandTypesScript.SKILL or command.command_type == CommandTypesScript.ULTIMATE:
        return skill_definition.mp_cost
    return 0

func _execute_switch_action(queued_action, battle_state):
    var result = ActionResultScript.new()
    var command = queued_action.command
    var side_state = battle_state.get_side(command.side_id)
    if side_state == null or not side_state.has_bench_unit(command.target_unit_id):
        result.result_type = "invalid_battle"
        result.invalid_battle_code = ErrorCodesScript.INVALID_SWITCH_TARGET_NOT_BENCH
        return result
    var actor = battle_state.get_unit(command.actor_id)
    var target_unit = battle_state.get_unit(command.target_unit_id)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.STATE_SWITCH,
        battle_state,
        {
            "source_instance_id": actor.unit_instance_id,
            "target_instance_id": target_unit.unit_instance_id if target_unit != null else null,
            "priority": queued_action.priority,
            "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
            "leave_reason": "manual_switch",
            "payload_summary": "%s switched to %s" % [actor.public_id, target_unit.public_id if target_unit != null else "unknown"],
        }
    ))
    side_state.bench_order.append(actor.unit_instance_id)
    leave_service.leave_unit(battle_state, actor, "manual_switch")
    var bench_index: int = side_state.bench_order.find(command.target_unit_id)
    if bench_index >= 0:
        side_state.bench_order.remove_at(bench_index)
    side_state.set_active_unit(ContentSchemaScript.ACTIVE_SLOT_PRIMARY, command.target_unit_id)
    target_unit.leave_state = LeaveStatesScript.ACTIVE
    target_unit.leave_reason = null
    target_unit.has_acted = true
    target_unit.action_window_passed = true
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.STATE_ENTER,
        battle_state,
        {
            "source_instance_id": target_unit.unit_instance_id,
            "target_instance_id": target_unit.unit_instance_id,
            "target_slot": ContentSchemaScript.ACTIVE_SLOT_PRIMARY,
            "payload_summary": "%s entered battle" % target_unit.public_id,
        }
    ))
    result.result_type = "resolved"
    return result

func _resolve_hit(command, skill_definition, battle_state) -> Dictionary:
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT or command.command_type == CommandTypesScript.TIMEOUT_DEFAULT:
        return {"hit": true, "hit_roll": null}
    var hit_info: Dictionary = hit_service.roll_hit(skill_definition.accuracy, rng_service)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    return hit_info

func _is_action_target_valid(command, queued_action, resolved_target) -> bool:
    if command.command_type == CommandTypesScript.SWITCH:
        return true
    if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
        return true
    if resolved_target == null:
        return false
    return resolved_target.leave_state == LeaveStatesScript.ACTIVE and resolved_target.current_hp > 0

func _resolve_target_instance_id(queued_action, resolved_target):
    if resolved_target == null:
        return null
    if queued_action.target_snapshot.target_kind == ContentSchemaScript.TARGET_FIELD:
        return null
    return resolved_target.unit_instance_id

func _is_damage_action(command, skill_definition) -> bool:
    if command.command_type == CommandTypesScript.RESOURCE_FORCED_DEFAULT or command.command_type == CommandTypesScript.TIMEOUT_DEFAULT:
        return true
    return skill_definition != null and skill_definition.damage_kind != ContentSchemaScript.DAMAGE_KIND_NONE and skill_definition.power > 0

func _apply_direct_damage(queued_action, actor, target, skill_definition, battle_state) -> void:
    if target == null:
        return
    var power: int = 50
    var damage_kind: String = ContentSchemaScript.DAMAGE_KIND_PHYSICAL
    if skill_definition != null:
        power = skill_definition.power
        damage_kind = skill_definition.damage_kind
    var attack_value: int = actor.base_attack
    var defense_value: int = target.base_defense
    if damage_kind == ContentSchemaScript.DAMAGE_KIND_SPECIAL:
        attack_value = actor.base_sp_attack
        defense_value = target.base_sp_defense
    attack_value = stat_calculator.calc_effective_stat(attack_value, int(actor.stat_stages.get("attack" if damage_kind == ContentSchemaScript.DAMAGE_KIND_PHYSICAL else "sp_attack", 0)))
    defense_value = stat_calculator.calc_effective_stat(defense_value, int(target.stat_stages.get("defense" if damage_kind == ContentSchemaScript.DAMAGE_KIND_PHYSICAL else "sp_defense", 0)))
    var final_multiplier: float = rule_mod_service.get_final_multiplier(battle_state, actor.unit_instance_id)
    var damage_amount: int = damage_service.apply_final_mod(
        damage_service.calc_base_damage(battle_state.battle_level, power, attack_value, defense_value),
        final_multiplier
    )
    var before_hp: int = target.current_hp
    target.current_hp = clamp(target.current_hp - damage_amount, 0, target.max_hp)
    var value_change = _build_value_change(target.unit_instance_id, "hp", before_hp, target.current_hp)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_DAMAGE,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": target.unit_instance_id,
            "priority": queued_action.priority,
            "target_slot": queued_action.target_snapshot.target_slot,
            "value_changes": [value_change],
            "payload_summary": "%s dealt %d damage to %s" % [actor.public_id, damage_amount, target.public_id],
        }
    ))

func _apply_default_recoil(queued_action, actor, battle_state) -> void:
    var recoil_amount: int = max(1, int(floor(float(actor.max_hp) / 4.0)))
    var before_hp: int = actor.current_hp
    actor.current_hp = clamp(actor.current_hp - recoil_amount, 0, actor.max_hp)
    var value_change = _build_value_change(actor.unit_instance_id, "hp", before_hp, actor.current_hp)
    battle_logger.append_event(log_event_builder.build_event(
        EventTypesScript.EFFECT_DAMAGE,
        battle_state,
        {
            "source_instance_id": queued_action.action_id,
            "target_instance_id": actor.unit_instance_id,
            "priority": queued_action.priority,
            "value_changes": [value_change],
            "payload_summary": "%s recoil %d" % [actor.public_id, recoil_amount],
        }
    ))

func _dispatch_skill_effects(effect_ids: PackedStringArray, trigger_name: String, queued_action, actor, battle_state, content_index, result) -> void:
    if effect_ids.is_empty():
        return
    var effect_events = trigger_dispatcher.collect_events(
        trigger_name,
        battle_state,
        content_index,
        effect_ids,
        actor.unit_instance_id,
        queued_action.action_id,
        2,
        queued_action.speed_snapshot,
        battle_state.chain_context
    )
    if effect_events.is_empty():
        return
    battle_state.pending_effect_queue = effect_events
    var sorted_events = effect_queue_service.sort_events(effect_events, rng_service)
    battle_state.rng_stream_index = rng_service.get_stream_index()
    for effect_event in sorted_events:
        payload_executor.execute_effect_event(effect_event, battle_state, content_index)
        result.generated_effects.append(effect_event)
    battle_state.pending_effect_queue.clear()

func _build_value_change(entity_id: String, resource_name: String, before_value: int, after_value: int):
    var value_change = ValueChangeScript.new()
    value_change.entity_id = entity_id
    value_change.resource_name = resource_name
    value_change.before_value = before_value
    value_change.after_value = after_value
    value_change.delta = after_value - before_value
    return value_change
