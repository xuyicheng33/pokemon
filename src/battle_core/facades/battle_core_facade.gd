extends RefCounted
class_name BattleCoreFacade

const BattleContentIndexScript := preload("res://src/battle_core/content/battle_content_index.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")

var id_factory
var rng_service
var battle_initializer
var legal_action_service
var command_builder
var turn_loop_controller
var replay_runner

var _sessions: Dictionary = {}

func initialize_battle(input_payload: Dictionary) -> Dictionary:
    assert(input_payload != null, "BattleCoreFacade.initialize_battle requires input payload")
    assert(input_payload.has("battle_setup"), "BattleCoreFacade.initialize_battle requires battle_setup")
    assert(input_payload.has("content_snapshot_paths"), "BattleCoreFacade.initialize_battle requires content_snapshot_paths")
    _assert_core_dependencies()
    var battle_seed: int = int(input_payload.get("battle_seed", 0))
    id_factory.reset()
    rng_service.reset(battle_seed)
    var content_index = BattleContentIndexScript.new()
    content_index.load_snapshot(input_payload["content_snapshot_paths"])
    var battle_state = BattleStateScript.new()
    battle_state.battle_id = id_factory.next_id("battle")
    battle_state.seed = battle_seed
    battle_state.rng_stream_index = rng_service.get_stream_index()
    battle_initializer.initialize_battle(battle_state, content_index, input_payload["battle_setup"])
    _sessions[battle_state.battle_id] = {
        "battle_state": battle_state,
        "content_index": content_index,
    }
    var public_snapshot = _build_public_snapshot_from_state(battle_state, content_index)
    return {
        "battle_id": battle_state.battle_id,
        "public_snapshot": public_snapshot,
        "prebattle_public_teams": public_snapshot.get("prebattle_public_teams", []),
    }

func get_legal_actions(battle_id: String, side_id: String):
    _assert_core_dependencies()
    var session = _get_session_or_fail(battle_id)
    return legal_action_service.get_legal_actions(session["battle_state"], side_id, session["content_index"])

func build_command(input_payload: Dictionary):
    _assert_core_dependencies()
    return command_builder.build_command(input_payload)

func run_turn(battle_id: String, commands: Array) -> Dictionary:
    _assert_core_dependencies()
    var session = _get_session_or_fail(battle_id)
    var battle_state = session["battle_state"]
    turn_loop_controller.run_turn(battle_state, session["content_index"], commands)
    return {
        "battle_id": battle_id,
        "public_snapshot": _build_public_snapshot_from_state(battle_state, session["content_index"]),
    }

func run_replay(replay_input) -> Dictionary:
    _assert_core_dependencies()
    var replay_output = replay_runner.run_replay(replay_input)
    return {
        "replay_output": replay_output,
        "public_snapshot": _build_public_snapshot_from_state(replay_output.final_battle_state),
    }

func build_public_snapshot(battle_id: String) -> Dictionary:
    var session = _get_session_or_fail(battle_id)
    return _build_public_snapshot_from_state(session["battle_state"], session["content_index"])

func close_battle(battle_id: String) -> void:
    _sessions.erase(battle_id)

func dispose() -> void:
    _sessions.clear()

func resolve_missing_dependency() -> String:
    if id_factory == null:
        return "id_factory"
    if rng_service == null:
        return "rng_service"
    if battle_initializer == null:
        return "battle_initializer"
    if legal_action_service == null:
        return "legal_action_service"
    if command_builder == null:
        return "command_builder"
    if turn_loop_controller == null:
        return "turn_loop_controller"
    if replay_runner == null:
        return "replay_runner"
    return ""

func _assert_core_dependencies() -> void:
    var missing_dependency := resolve_missing_dependency()
    assert(missing_dependency.is_empty(), "BattleCoreFacade missing dependency: %s" % missing_dependency)

func _get_session_or_fail(battle_id: String) -> Dictionary:
    assert(not battle_id.is_empty(), "BattleCoreFacade requires non-empty battle_id")
    var session: Variant = _sessions.get(battle_id, null)
    assert(session != null, "BattleCoreFacade unknown battle session: %s" % battle_id)
    return session

func _build_public_snapshot_from_state(battle_state, content_index = null) -> Dictionary:
    assert(battle_state != null, "BattleCoreFacade requires battle_state to build public snapshot")
    var field_snapshot = _build_public_field_snapshot(battle_state)
    var side_models: Array = []
    for side_state in battle_state.sides:
        var active_unit = side_state.get_active_unit()
        var bench_public_ids: Array[String] = []
        var team_units: Array = []
        for bench_unit_id in side_state.bench_order:
            var bench_unit = side_state.find_unit(str(bench_unit_id))
            if bench_unit != null:
                bench_public_ids.append(bench_unit.public_id)
        for unit_state in side_state.team_units:
            team_units.append(_build_public_unit_snapshot(side_state, unit_state))
        team_units.sort_custom(func(left, right): return String(left.get("public_id", "")) < String(right.get("public_id", "")))
        side_models.append({
            "side_id": side_state.side_id,
            "active_public_id": active_unit.public_id if active_unit != null else null,
            "active_hp": active_unit.current_hp if active_unit != null else null,
            "active_mp": active_unit.current_mp if active_unit != null else null,
            "bench_public_ids": bench_public_ids,
            "team_units": team_units,
        })
    return {
        "battle_id": battle_state.battle_id,
        "turn_index": battle_state.turn_index,
        "phase": battle_state.phase,
        "visibility_mode": battle_state.format_id,
        "field_id": field_snapshot["field_id"],
        "field": field_snapshot,
        "sides": side_models,
        "prebattle_public_teams": _build_prebattle_public_teams(battle_state, content_index),
        "battle_result": battle_state.battle_result.to_stable_dict() if battle_state.battle_result != null else null,
    }

func _build_public_unit_snapshot(side_state, unit_state) -> Dictionary:
    var is_active: bool = false
    var active_slot: Variant = null
    for slot_id in side_state.active_slots.keys():
        if str(side_state.active_slots[slot_id]) == unit_state.unit_instance_id:
            is_active = true
            active_slot = String(slot_id)
            break
    var effect_summaries: Array = []
    for effect_instance in unit_state.effect_instances:
        effect_summaries.append({
            "effect_definition_id": effect_instance.def_id,
            "remaining": effect_instance.remaining,
            "persists_on_switch": effect_instance.persists_on_switch,
        })
    effect_summaries.sort_custom(func(left, right): return String(left.get("effect_definition_id", "")) < String(right.get("effect_definition_id", "")))
    return {
        "public_id": unit_state.public_id,
        "definition_id": unit_state.definition_id,
        "display_name": unit_state.display_name,
        "current_hp": unit_state.current_hp,
        "current_mp": unit_state.current_mp,
        "max_hp": unit_state.max_hp,
        "max_mp": unit_state.max_mp,
        "stat_stages": unit_state.stat_stages.duplicate(true),
        "leave_state": unit_state.leave_state,
        "leave_reason": unit_state.leave_reason,
        "is_active": is_active,
        "active_slot": active_slot,
        "effect_instances": effect_summaries,
    }

func _build_public_field_snapshot(battle_state) -> Dictionary:
    if battle_state.field_state == null:
        return {
            "field_id": null,
            "remaining_turns": null,
            "creator_public_id": null,
        }
    return {
        "field_id": battle_state.field_state.field_def_id,
        "remaining_turns": battle_state.field_state.remaining_turns,
        "creator_public_id": _resolve_public_id_or_system(battle_state, battle_state.field_state.creator),
    }

func _build_prebattle_public_teams(battle_state, content_index) -> Array:
    if content_index == null:
        return []
    var side_models: Array = []
    for side_state in battle_state.sides:
        var unit_models: Array = []
        for unit_state in side_state.team_units:
            var unit_definition = content_index.units.get(unit_state.definition_id, null)
            if unit_definition == null:
                continue
            unit_models.append({
                "public_id": unit_state.public_id,
                "definition_id": unit_definition.id,
                "display_name": unit_definition.display_name,
                "level": battle_state.battle_level,
                "skill_ids": unit_definition.skill_ids,
                "ultimate_skill_id": unit_definition.ultimate_skill_id,
                "passive_skill_id": unit_definition.passive_skill_id,
                "passive_item_id": unit_definition.passive_item_id,
                "base_stats": {
                    "hp": unit_definition.base_hp,
                    "attack": unit_definition.base_attack,
                    "defense": unit_definition.base_defense,
                    "sp_attack": unit_definition.base_sp_attack,
                    "sp_defense": unit_definition.base_sp_defense,
                    "speed": unit_definition.base_speed,
                    "max_mp": unit_definition.max_mp,
                    "init_mp": unit_definition.init_mp,
                    "regen_per_turn": unit_definition.regen_per_turn,
                },
            })
        unit_models.sort_custom(func(left, right): return String(left.get("public_id", "")) < String(right.get("public_id", "")))
        side_models.append({
            "side_id": side_state.side_id,
            "units": unit_models,
        })
    return side_models

func _resolve_public_id_or_system(battle_state, source_id: String) -> Variant:
    if source_id.is_empty():
        return null
    var source_unit = battle_state.get_unit(source_id)
    if source_unit != null:
        return source_unit.public_id
    return source_id
