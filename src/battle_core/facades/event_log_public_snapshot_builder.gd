extends RefCounted
class_name EventLogPublicSnapshotBuilder

const SAFE_EVENT_FIELDS := [
	"battle_seed",
	"battle_rng_profile",
	"log_schema_version",
	"turn_index",
	"event_type",
	"event_chain_id",
	"event_step_id",
	"chain_origin",
	"trigger_name",
	"cause_event_id",
	"action_id",
	"action_queue_index",
	"command_type",
	"command_source",
	"priority",
	"target_slot",
	"action_window_passed",
	"has_acted",
	"leave_reason",
	"speed_tie_roll",
	"hit_roll",
	"effect_roll",
	"rng_stream_index",
	"select_deadline_ms",
	"select_timeout",
	"invalid_battle_code",
	"type_effectiveness",
	"payload_summary",
	"header_snapshot",
]

func build_public_snapshot(log_event, battle_state) -> Dictionary:
	if log_event == null:
		return {}
	var event_snapshot: Dictionary = {}
	for field_name in SAFE_EVENT_FIELDS:
		event_snapshot[field_name] = log_event.get(field_name)
	event_snapshot["field_change"] = _serialize_field_change(log_event.field_change)
	event_snapshot["value_changes"] = _build_public_value_changes(log_event.value_changes, battle_state)
	event_snapshot["actor_public_id"] = _resolve_public_id(battle_state, log_event.actor_id)
	event_snapshot["actor_definition_id"] = _resolve_definition_id(battle_state, log_event.actor_id)
	event_snapshot["target_public_id"] = _resolve_public_id(battle_state, log_event.target_instance_id)
	event_snapshot["target_definition_id"] = _resolve_definition_id(battle_state, log_event.target_instance_id)
	event_snapshot["killer_public_id"] = _resolve_public_id(battle_state, log_event.killer_id)
	event_snapshot["killer_definition_id"] = _resolve_definition_id(battle_state, log_event.killer_id)
	return event_snapshot

func _serialize_field_change(field_change) -> Variant:
	if field_change == null:
		return null
	return field_change.to_stable_dict()

func _build_public_value_changes(value_changes: Array, battle_state) -> Array:
	var public_changes: Array = []
	for value_change in value_changes:
		if value_change == null:
			continue
		public_changes.append({
			"entity_public_id": _resolve_public_id(battle_state, value_change.entity_id),
			"entity_definition_id": _resolve_definition_id(battle_state, value_change.entity_id),
			"resource_name": value_change.resource_name,
			"before_value": value_change.before_value,
			"after_value": value_change.after_value,
			"delta": value_change.delta,
		})
	return public_changes

func _resolve_public_id(battle_state, runtime_unit_id) -> Variant:
	var unit_state = _resolve_unit_state(battle_state, runtime_unit_id)
	if unit_state == null:
		return null
	return unit_state.public_id

func _resolve_definition_id(battle_state, runtime_unit_id) -> Variant:
	var unit_state = _resolve_unit_state(battle_state, runtime_unit_id)
	if unit_state == null:
		return null
	return unit_state.definition_id

func _resolve_unit_state(battle_state, runtime_unit_id):
	if battle_state == null:
		return null
	var normalized_id := str(runtime_unit_id)
	if normalized_id.is_empty():
		return null
	return battle_state.get_unit(normalized_id)
