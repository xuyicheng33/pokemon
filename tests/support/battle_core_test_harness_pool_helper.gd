extends RefCounted
class_name BattleCoreTestHarnessPoolHelper

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const EventTypesScript := preload("res://src/shared/event_types.gd")

var _core_pool: Array = []
var _manager_pool: Array = []

func build_core() -> Dictionary:
	var composer = BattleCoreComposerScript.new()
	if composer == null:
		return {"error": "BattleCoreComposer init failed"}
	var core = composer.compose()
	if core == null:
		return {"error": "compose returned null"}
	var required_services: Array[String] = [
		"command_builder",
		"replay_runner",
		"battle_initializer",
		"turn_loop_controller",
		"battle_logger",
		"id_factory",
		"rng_service",
		"public_snapshot_builder",
	]
	for service_name in required_services:
		if core.service(service_name) == null:
			return {"error": "missing core service: %s" % service_name}
	_core_pool.append(core)
	return {"core": core}

func build_manager() -> Dictionary:
	var composer = BattleCoreComposerScript.new()
	if composer == null:
		return {"error": "BattleCoreComposer init failed"}
	var manager = composer.compose_manager()
	if manager == null:
		return {"error": "compose_manager returned null"}
	var missing_dependency := String(manager.resolve_missing_dependency())
	if not missing_dependency.is_empty():
		return {"error": "missing manager port: %s" % missing_dependency}
	_manager_pool.append(manager)
	return {"manager": manager, "composer": composer}

func dispose_core_pool() -> void:
	for core in _core_pool:
		if core != null and core.has_method("dispose"):
			core.dispose()
	_core_pool.clear()
	for manager in _manager_pool:
		if manager != null and manager.has_method("dispose"):
			manager.dispose()
	_manager_pool.clear()

func find_last_event(event_log: Array, event_type: String):
	for i in range(event_log.size() - 1, -1, -1):
		if event_log[i].event_type == event_type:
			return event_log[i]
	return null

func extract_damage_from_log(event_log: Array, attacker_public_id: String) -> int:
	for ev in event_log:
		if ev.event_type == EventTypesScript.EFFECT_DAMAGE and String(ev.payload_summary).begins_with("%s dealt " % attacker_public_id) and not ev.value_changes.is_empty():
			return abs(int(ev.value_changes[0].delta))
	return 0
