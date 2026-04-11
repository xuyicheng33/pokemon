extends RefCounted
class_name BattleCoreWiringSpecs

const CommandsWiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs/battle_core_wiring_specs_commands.gd")
const TurnWiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs/battle_core_wiring_specs_turn.gd")
const LifecycleWiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs/battle_core_wiring_specs_lifecycle.gd")
const PassivesWiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs/battle_core_wiring_specs_passives.gd")
const EffectsCoreWiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs/battle_core_wiring_specs_effects_core.gd")
const PayloadHandlerWiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs/battle_core_wiring_specs_payload_handlers.gd")
const ActionWiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs/battle_core_wiring_specs_actions.gd")

const RESET_SPECS := [
	{"owner": "rule_mod_value_resolver", "field": "last_error_code", "value": null},
]

static func wiring_specs() -> Array:
	return (
		CommandsWiringSpecsScript.WIRING_SPECS
		+ TurnWiringSpecsScript.WIRING_SPECS
		+ LifecycleWiringSpecsScript.WIRING_SPECS
		+ PassivesWiringSpecsScript.WIRING_SPECS
		+ EffectsCoreWiringSpecsScript.wiring_specs()
		+ PayloadHandlerWiringSpecsScript.wiring_specs()
		+ ActionWiringSpecsScript.WIRING_SPECS
	)

static func reset_specs() -> Array:
	return RESET_SPECS.duplicate(true)
