extends RefCounted
class_name BattleResultServiceChainBuilder

const BattlePhasesScript := preload("res://src/shared/battle_phases.gd")
const ChainContextScript := preload("res://src/battle_core/contracts/chain_context.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

func build_system_chain(id_factory, command_type: String) -> Variant:
	var chain_context = ChainContextScript.new()
	chain_context.event_chain_id = id_factory.next_id("chain")
	chain_context.chain_origin = _resolve_chain_origin(command_type)
	chain_context.command_type = command_type
	chain_context.command_source = "system"
	chain_context.select_deadline_ms = null
	chain_context.select_timeout = null
	return chain_context

func build_battle_end_chain(id_factory, resolved_phase: String, battle_state) -> Variant:
	if battle_state != null and battle_state.chain_context != null:
		var existing_chain_context = battle_state.chain_context
		if String(existing_chain_context.chain_origin) == "action":
			return existing_chain_context.copy_shallow()
	match resolved_phase:
		BattlePhasesScript.BATTLE_INIT:
			return build_system_chain(id_factory, EventTypesScript.SYSTEM_BATTLE_INIT)
		BattlePhasesScript.TURN_START:
			return build_system_chain(id_factory, EventTypesScript.SYSTEM_TURN_START)
		BattlePhasesScript.TURN_END, BattlePhasesScript.VICTORY_CHECK:
			return build_system_chain(id_factory, EventTypesScript.SYSTEM_TURN_END)
		_:
			return build_system_chain(id_factory, "system:replace")

func _resolve_chain_origin(command_type: String) -> String:
	match command_type:
		EventTypesScript.SYSTEM_BATTLE_INIT:
			return "battle_init"
		EventTypesScript.SYSTEM_TURN_START:
			return "turn_start"
		EventTypesScript.SYSTEM_TURN_END, EventTypesScript.SYSTEM_TURN_LIMIT:
			return "turn_end"
		_:
			return "system_replace"
