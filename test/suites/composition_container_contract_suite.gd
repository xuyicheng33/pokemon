extends "res://tests/support/gdunit_suite_bridge.gd"

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const BattleCoreContainerScript := preload("res://src/composition/battle_core_container.gd")

class DummyService:
	extends RefCounted

	var dependency = "wired"
	var reset_value = "dirty"


func test_battle_core_container_api_contract() -> void:
	var dummy_container = BattleCoreContainerScript.new()
	if dummy_container == null:
		fail("BattleCoreContainer init failed")
		return
	var owner_service = DummyService.new()
	var dependency = DummyService.new()
	var owner_slot := "owner"
	var dependency_slot := "dependency"
	dummy_container.set_service(owner_slot, owner_service)
	dummy_container.set_service(dependency_slot, dependency)
	if dummy_container.service(owner_slot) != owner_service:
		fail("BattleCoreContainer.service should return the registered instance")
		return
	if not dummy_container.has_service(dependency_slot):
		fail("BattleCoreContainer.has_service should reflect registered instances")
		return
	dummy_container.clear_service(dependency_slot)
	if dummy_container.has_service(dependency_slot):
		fail("BattleCoreContainer.clear_service should remove the slot")
		return
	dummy_container.set_service(dependency_slot, dependency)
	dummy_container.configure_dispose_specs(
		PackedStringArray([owner_slot, dependency_slot]),
		[{"owner": owner_slot, "dependency": dependency_slot, "source": dependency_slot}],
		[{"owner": owner_slot, "field": "reset_value", "value": "clean"}]
	)
	dummy_container.dispose()
	if owner_service.dependency != null:
		fail("BattleCoreContainer.dispose should null injected dependencies")
		return
	if owner_service.reset_value != "clean":
		fail("BattleCoreContainer.dispose should apply reset specs")
		return
	if dummy_container.has_service(owner_slot) or dummy_container.has_service(dependency_slot):
		fail("BattleCoreContainer.dispose should clear registered services")
		return

func test_composer_build_core_container_contract() -> void:
	var composer = BattleCoreComposerScript.new()
	if composer == null:
		fail("BattleCoreComposer init failed")
		return
	var core = composer.compose()
	if core == null:
		fail(composer.last_error_message if not composer.last_error_message.is_empty() else "compose returned null")
		return
	if not core.has_method("service") or not core.has_method("set_service") or not core.has_method("clear_service"):
		fail("BattleCoreContainer public API must stay dictionary-backed")
		return
	if not core.has_service("turn_loop_controller"):
		fail("compose should expose turn_loop_controller via has_service")
		return
	if core.service("turn_loop_controller") == null:
		fail("compose should wire turn_loop_controller")
		return
	core.dispose()

func test_composer_build_manager_contract() -> void:
	var manager_payload = _harness.build_manager()
	if manager_payload.has("error"):
		fail(str(manager_payload["error"]))
		return
	var manager = manager_payload["manager"]
	if not String(manager.resolve_missing_dependency()).is_empty():
		fail("compose_manager should keep manager ports wired")
		return
	for property_info in manager.get_property_list():
		var property_name := String(property_info.get("name", ""))
		if property_name == "container_factory" or property_name == "command_builder" or property_name == "command_id_factory" or property_name == "public_snapshot_builder":
			fail("compose_manager should keep raw manager ports private")
			return

