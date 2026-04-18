extends "res://test/support/gdunit_suite_bridge.gd"

const CommandTypesScript := preload("res://src/battle_core/commands/command_types.gd")
const PlayerSelectionAdapterScript := preload("res://src/adapters/player_selection_adapter.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")
const BattleStateScript := preload("res://src/battle_core/runtime/battle_state.gd")
const SideStateScript := preload("res://src/battle_core/runtime/side_state.gd")
const UnitStateScript := preload("res://src/battle_core/runtime/unit_state.gd")
const EffectInstanceScript := preload("res://src/battle_core/runtime/effect_instance.gd")
const PublicSnapshotBuilderScript := preload("res://src/battle_core/facades/public_snapshot_builder.gd")
const ManagerContractTestHelperScript := preload("res://tests/support/manager_contract_test_helper.gd")

@warning_ignore("unused_private_class_variable")
var _helper = ManagerContractTestHelperScript.new()

func _build_public_effect_instance(instance_id: String, definition_id: String, remaining: int, persists_on_switch: bool):
	var effect_instance = EffectInstanceScript.new()
	effect_instance.instance_id = instance_id
	effect_instance.def_id = definition_id
	effect_instance.remaining = remaining
	effect_instance.persists_on_switch = persists_on_switch
	return effect_instance
