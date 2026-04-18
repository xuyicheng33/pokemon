extends RefCounted
class_name FaintLeaveReplacementService

const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")

const COMPOSE_DEPS := [
	{
		"field": "leave_service",
		"source": "leave_service",
		"nested": true,
	},
	{
		"field": "replacement_service",
		"source": "replacement_service",
		"nested": true,
	},
]

const LeaveStatesScript := preload("res://src/shared/leave_states.gd")

var leave_service
var replacement_service

func resolve_missing_dependency() -> String:
	return ServiceDependencyContractHelperScript.resolve_missing_dependency(self)


func collect_pending_fainted_units(battle_state) -> Array:
	var fainted_units: Array = []
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit == null:
			continue
		if active_unit.current_hp <= 0 and active_unit.leave_state == LeaveStatesScript.ACTIVE:
			active_unit.leave_state = LeaveStatesScript.FAINTED_PENDING_LEAVE
			active_unit.leave_reason = "faint"
			fainted_units.append(active_unit)
	return fainted_units

func resolve_fainted_units_leave(battle_state, content_index, fainted_units: Array) -> Variant:
	for fainted_unit in fainted_units:
		leave_service.leave_unit(battle_state, fainted_unit, "faint", content_index)
		if leave_service.invalid_battle_code() != null:
			return leave_service.invalid_battle_code()
	return null

func resolve_faint_replacements(battle_state) -> Dictionary:
	var entered_unit_ids: Array = []
	for side_state in battle_state.sides:
		if side_state.get_active_unit() != null:
			continue
		var replacement_result: Dictionary = replacement_service.resolve_replacement(battle_state, side_state, "faint")
		var replacement_invalid_code = replacement_result.get("invalid_code", null)
		if replacement_invalid_code != null:
			return {"entered_unit_ids": [], "invalid_code": replacement_invalid_code}
		var entered_unit = replacement_result.get("entered_unit", null)
		if entered_unit != null:
			entered_unit_ids.append(entered_unit.unit_instance_id)
	return {"entered_unit_ids": entered_unit_ids, "invalid_code": null}

func has_pending_faint_active(battle_state) -> bool:
	for side_state in battle_state.sides:
		var active_unit = side_state.get_active_unit()
		if active_unit == null:
			continue
		if active_unit.current_hp <= 0 and active_unit.leave_state == LeaveStatesScript.ACTIVE:
			return true
	return false

func collect_unit_ids(units: Array) -> Array:
	var unit_ids: Array = []
	for unit in units:
		unit_ids.append(unit.unit_instance_id)
	return unit_ids
