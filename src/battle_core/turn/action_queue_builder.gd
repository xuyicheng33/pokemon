extends RefCounted
class_name ActionQueueBuilder

const QueuedActionScript := preload("res://src/battle_core/contracts/queued_action.gd")
const TargetSnapshotScript := preload("res://src/battle_core/contracts/target_snapshot.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")

var id_factory
var rng_service
var stat_calculator

func build_queue(commands: Array, battle_state, content_index) -> Array:
    var queued_actions: Array = []
    var grouped_actions: Dictionary = {}
    for command in commands:
        var queued_action = QueuedActionScript.new()
        queued_action.action_id = id_factory.next_id("action")
        queued_action.command = command
        queued_action.actor_snapshot_id = command.actor_id
        queued_action.priority = _resolve_priority(command, battle_state, content_index)
        queued_action.speed_snapshot = _resolve_speed_snapshot(command, battle_state)
        queued_action.target_snapshot = _build_target_snapshot(command, battle_state, content_index)
        var group_key := "%d|%d" % [queued_action.priority, queued_action.speed_snapshot]
        if not grouped_actions.has(group_key):
            grouped_actions[group_key] = []
        grouped_actions[group_key].append(queued_action)
        queued_actions.append(queued_action)
    for group_key in grouped_actions.keys():
        var group: Array = grouped_actions[group_key]
        if group.size() > 1:
            for queued_action in group:
                queued_action.speed_tie_roll = rng_service.next_float()
    battle_state.rng_stream_index = rng_service.get_stream_index()
    queued_actions.sort_custom(_sort_queued_actions)
    for queue_index in range(queued_actions.size()):
        queued_actions[queue_index].queue_index = queue_index
    _mark_domain_clash_protection(queued_actions, content_index)
    return queued_actions

func _resolve_priority(command, battle_state, content_index) -> int:
    match command.command_type:
        CommandTypesScript.SWITCH:
            return 4
        CommandTypesScript.RESOURCE_FORCED_DEFAULT, CommandTypesScript.WAIT:
            return 0
        CommandTypesScript.SKILL, CommandTypesScript.ULTIMATE:
            var skill_definition = content_index.skills.get(command.skill_id)
            assert(skill_definition != null, "Missing skill definition: %s" % command.skill_id)
            return skill_definition.priority
        _:
            return 0

func _resolve_speed_snapshot(command, battle_state) -> int:
    var actor = battle_state.get_unit(command.actor_id)
    assert(actor != null, "Missing action actor: %s" % command.actor_id)
    actor.last_effective_speed = stat_calculator.calc_effective_stat(actor.base_speed, int(actor.stat_stages.get("speed", 0)))
    return actor.last_effective_speed

func _build_target_snapshot(command, battle_state, content_index):
    var target_snapshot = TargetSnapshotScript.new()
    match command.command_type:
        CommandTypesScript.SWITCH:
            target_snapshot.target_kind = "bench_unit"
            target_snapshot.target_unit_id = command.target_unit_id
            return target_snapshot
        CommandTypesScript.WAIT:
            target_snapshot.target_kind = ContentSchemaScript.TARGET_NONE
            return target_snapshot
        CommandTypesScript.RESOURCE_FORCED_DEFAULT:
            target_snapshot.target_kind = ContentSchemaScript.TARGET_ENEMY_ACTIVE
            target_snapshot.target_slot = ContentSchemaScript.ACTIVE_SLOT_PRIMARY
        CommandTypesScript.SKILL, CommandTypesScript.ULTIMATE:
            var skill_definition = content_index.skills.get(command.skill_id)
            assert(skill_definition != null, "Missing skill definition: %s" % command.skill_id)
            target_snapshot.target_kind = skill_definition.targeting
            if skill_definition.targeting == ContentSchemaScript.TARGET_ENEMY_ACTIVE:
                target_snapshot.target_slot = ContentSchemaScript.ACTIVE_SLOT_PRIMARY
            elif skill_definition.targeting == ContentSchemaScript.TARGET_SELF:
                target_snapshot.target_unit_id = command.actor_id
            elif skill_definition.targeting == ContentSchemaScript.TARGET_FIELD:
                target_snapshot.target_slot = "field"
        _:
            target_snapshot.target_kind = ContentSchemaScript.TARGET_ENEMY_ACTIVE
            target_snapshot.target_slot = ContentSchemaScript.ACTIVE_SLOT_PRIMARY
    if target_snapshot.target_kind == ContentSchemaScript.TARGET_ENEMY_ACTIVE:
        var opponent_side = battle_state.get_opponent_side(command.side_id)
        var target_unit = opponent_side.get_active_unit()
        target_snapshot.target_unit_id = target_unit.unit_instance_id if target_unit != null else null
    return target_snapshot

func _sort_queued_actions(left, right) -> bool:
    if left.priority != right.priority:
        return left.priority > right.priority
    if left.speed_snapshot != right.speed_snapshot:
        return left.speed_snapshot > right.speed_snapshot
    if left.speed_tie_roll != null and right.speed_tie_roll != null and left.speed_tie_roll != right.speed_tie_roll:
        return left.speed_tie_roll < right.speed_tie_roll
    return left.action_id < right.action_id

func _mark_domain_clash_protection(queued_actions: Array, content_index) -> void:
    var first_domain_action_by_side: Dictionary = {}
    for queued_action in queued_actions:
        var command = queued_action.command
        if command == null:
            continue
        if command.command_type != CommandTypesScript.SKILL and command.command_type != CommandTypesScript.ULTIMATE:
            continue
        var skill_definition = content_index.skills.get(command.skill_id)
        if skill_definition == null or not content_index.is_domain_skill(command.skill_id):
            continue
        if not first_domain_action_by_side.has(command.side_id):
            first_domain_action_by_side[command.side_id] = queued_action
    if first_domain_action_by_side.size() < 2:
        return
    var protected_domain_actions: Array = first_domain_action_by_side.values()
    for domain_action in protected_domain_actions:
        domain_action.domain_clash_protected = true
    protected_domain_actions.sort_custom(func(left, right): return left.queue_index < right.queue_index)
    protected_domain_actions[0].defer_domain_success_effects = true
