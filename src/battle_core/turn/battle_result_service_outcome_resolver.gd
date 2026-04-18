extends RefCounted
class_name BattleResultServiceOutcomeResolver

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func resolve_initialization_victory(chain_builder, id_factory, battle_logger, log_event_builder, battle_state) -> bool:
	return _resolve_victory(
		chain_builder,
		id_factory,
		battle_logger,
		log_event_builder,
		battle_state,
		"battle finished during initialization"
	)

func resolve_standard_victory(chain_builder, id_factory, battle_logger, log_event_builder, battle_state) -> bool:
	return _resolve_victory(
		chain_builder,
		id_factory,
		battle_logger,
		log_event_builder,
		battle_state,
		"battle finished by elimination"
	)

func resolve_surrender(chain_builder, id_factory, battle_logger, log_event_builder, battle_state, commands: Array) -> bool:
	var surrendering_sides: Array = []
	for command in commands:
		if command.command_type == CommandTypesScript.SURRENDER:
			surrendering_sides.append(command.side_id)
	if surrendering_sides.is_empty():
		return false
	var resolved_phase: String = battle_state.phase
	battle_state.battle_result.finished = true
	battle_state.phase = BattlePhasesScript.FINISHED
	if surrendering_sides.size() == 1:
		var winner_side = battle_state.get_opponent_side(surrendering_sides[0])
		battle_state.battle_result.winner_side_id = winner_side.side_id if winner_side != null else null
		battle_state.battle_result.result_type = "win"
	else:
		battle_state.battle_result.winner_side_id = null
		battle_state.battle_result.result_type = "draw"
	battle_state.battle_result.reason = "surrender"
	battle_state.chain_context = chain_builder.build_battle_end_chain(id_factory, resolved_phase, battle_state)
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.RESULT_BATTLE_END,
		battle_state,
		{
			"source_instance_id": "system:battle_end",
			"payload_summary": "battle ended by surrender",
		}
	))
	return true

func resolve_turn_limit(chain_builder, id_factory, battle_logger, log_event_builder, turn_limit_scoring_service, battle_state) -> void:
	var scored_sides: Array = turn_limit_scoring_service.build_scored_sides(battle_state)
	battle_state.battle_result.finished = true
	battle_state.phase = BattlePhasesScript.FINISHED
	if turn_limit_scoring_service.scores_tied(scored_sides):
		battle_state.battle_result.winner_side_id = null
		battle_state.battle_result.result_type = "draw"
	else:
		battle_state.battle_result.winner_side_id = scored_sides[0]["side_id"]
		battle_state.battle_result.result_type = "win"
	battle_state.battle_result.reason = "turn_limit"
	battle_state.chain_context = chain_builder.build_system_chain(id_factory, EventTypesScript.SYSTEM_TURN_LIMIT)
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.SYSTEM_TURN_LIMIT,
		battle_state,
		{
			"source_instance_id": "system:turn_limit",
			"payload_summary": "turn limit resolved",
		}
	))
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.RESULT_BATTLE_END,
		battle_state,
		{
			"source_instance_id": "system:battle_end",
			"payload_summary": "battle ended by turn limit",
		}
	))

func _resolve_victory(chain_builder, id_factory, battle_logger, log_event_builder, battle_state, payload_summary: String) -> bool:
	var alive_side_ids: Array = []
	for side_state in battle_state.sides:
		if _side_has_available_unit(side_state):
			alive_side_ids.append(side_state.side_id)
	if alive_side_ids.size() == battle_state.sides.size():
		return false
	var resolved_phase: String = battle_state.phase
	battle_state.battle_result.finished = true
	battle_state.phase = BattlePhasesScript.FINISHED
	if alive_side_ids.is_empty():
		battle_state.battle_result.winner_side_id = null
		battle_state.battle_result.result_type = "draw"
		battle_state.battle_result.reason = "double_faint"
	else:
		battle_state.battle_result.winner_side_id = alive_side_ids[0]
		battle_state.battle_result.result_type = "win"
		battle_state.battle_result.reason = "elimination"
	battle_state.chain_context = chain_builder.build_battle_end_chain(id_factory, resolved_phase, battle_state)
	battle_logger.append_event(log_event_builder.build_event(
		EventTypesScript.RESULT_BATTLE_END,
		battle_state,
		{
			"source_instance_id": "system:battle_end",
			"payload_summary": payload_summary,
		}
	))
	return true

func _side_has_available_unit(side_state) -> bool:
	for unit_state in side_state.team_units:
		if unit_state.current_hp > 0:
			return true
	return false
