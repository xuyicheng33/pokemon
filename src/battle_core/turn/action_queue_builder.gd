extends RefCounted
class_name ActionQueueBuilder

const QueuedActionScript := preload("res://src/battle_core/contracts/queued_action.gd")
const TargetSnapshotScript := preload("res://src/battle_core/contracts/target_snapshot.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const ContentSchemaScript := preload("res://src/battle_core/content/content_schema.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

var id_factory
var rng_service
var stat_calculator
var domain_clash_orchestrator
var last_invalid_battle_code: Variant = null

func invalid_battle_code() -> Variant:
    return last_invalid_battle_code

func resolve_missing_dependency() -> String:
    if id_factory == null:
        return "id_factory"
    if rng_service == null:
        return "rng_service"
    if stat_calculator == null:
        return "stat_calculator"
    if domain_clash_orchestrator == null:
        return "domain_clash_orchestrator"
    var domain_missing := str(domain_clash_orchestrator.resolve_missing_dependency())
    if not domain_missing.is_empty():
        return "domain_clash_orchestrator.%s" % domain_missing
    return ""

func build_queue(commands: Array, battle_state, content_index) -> Array:
    last_invalid_battle_code = null
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
        if last_invalid_battle_code != null:
            return []
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
    domain_clash_orchestrator.mark_domain_clash_protection(queued_actions, content_index)
    if domain_clash_orchestrator.invalid_battle_code() != null:
        last_invalid_battle_code = domain_clash_orchestrator.invalid_battle_code()
        return []
    return queued_actions

func _resolve_priority(command, _battle_state, content_index) -> int:
    match command.command_type:
        CommandTypesScript.SWITCH:
            return 4
        CommandTypesScript.RESOURCE_FORCED_DEFAULT, CommandTypesScript.WAIT:
            return 0
        CommandTypesScript.SKILL, CommandTypesScript.ULTIMATE:
            var skill_definition = content_index.skills.get(command.skill_id)
            if skill_definition == null:
                last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
                return 0
            return skill_definition.priority
        _:
            return 0

func _resolve_speed_snapshot(command, battle_state) -> int:
    var actor = battle_state.get_unit(command.actor_id)
    if actor == null:
        last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
        return 0
    actor.last_effective_speed = stat_calculator.calc_effective_stat(actor.base_speed, actor.get_effective_stage("speed"))
    return actor.last_effective_speed

func _build_target_snapshot(command, battle_state, content_index) -> Variant:
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
            if skill_definition == null:
                last_invalid_battle_code = ErrorCodesScript.INVALID_STATE_CORRUPTION
                return target_snapshot
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
