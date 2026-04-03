extends RefCounted
class_name CompositionContainerContractSuite

const BattleCoreComposerScript := preload("res://src/composition/battle_core_composer.gd")
const BattleCoreContainerScript := preload("res://src/composition/battle_core_container.gd")

class DummyService:
	extends RefCounted

	var dependency = "wired"
	var reset_value = "dirty"

func register_tests(runner, failures: Array[String], harness) -> void:
	runner.run_test("battle_core_container_api_contract", failures, Callable(self, "_test_battle_core_container_api_contract"))
	runner.run_test("composer_build_core_container_contract", failures, Callable(self, "_test_composer_build_core_container_contract"))
	runner.run_test("composer_build_manager_contract", failures, Callable(self, "_test_composer_build_manager_contract").bind(harness))

func _test_battle_core_container_api_contract() -> Dictionary:
	var dummy_container = BattleCoreContainerScript.new()
	if dummy_container == null:
		return {"ok": false, "error": "BattleCoreContainer init failed"}
	var owner = DummyService.new()
	var dependency = DummyService.new()
	var owner_slot := "owner"
	var dependency_slot := "dependency"
	dummy_container.set_service(owner_slot, owner)
	dummy_container.set_service(dependency_slot, dependency)
	if dummy_container.service(owner_slot) != owner:
		return {"ok": false, "error": "BattleCoreContainer.service should return the registered instance"}
	if not dummy_container.has_service(dependency_slot):
		return {"ok": false, "error": "BattleCoreContainer.has_service should reflect registered instances"}
	dummy_container.clear_service(dependency_slot)
	if dummy_container.has_service(dependency_slot):
		return {"ok": false, "error": "BattleCoreContainer.clear_service should remove the slot"}
	dummy_container.set_service(dependency_slot, dependency)
	dummy_container.configure_dispose_specs(
		PackedStringArray([owner_slot, dependency_slot]),
		[{"owner": owner_slot, "dependency": dependency_slot, "source": dependency_slot}],
		[{"owner": owner_slot, "field": "reset_value", "value": "clean"}]
	)
	dummy_container.dispose()
	if owner.dependency != null:
		return {"ok": false, "error": "BattleCoreContainer.dispose should null injected dependencies"}
	if owner.reset_value != "clean":
		return {"ok": false, "error": "BattleCoreContainer.dispose should apply reset specs"}
	if dummy_container.has_service(owner_slot) or dummy_container.has_service(dependency_slot):
		return {"ok": false, "error": "BattleCoreContainer.dispose should clear registered services"}
	return {"ok": true}

func _test_composer_build_core_container_contract() -> Dictionary:
	var composer = BattleCoreComposerScript.new()
	if composer == null:
		return {"ok": false, "error": "BattleCoreComposer init failed"}
	var core = composer.compose()
	if core == null:
		return {"ok": false, "error": composer.last_error_message if not composer.last_error_message.is_empty() else "compose returned null"}
	if not core.has_method("service") or not core.has_method("set_service") or not core.has_method("clear_service"):
		return {"ok": false, "error": "BattleCoreContainer public API must stay dictionary-backed"}
	if not core.has_service("turn_loop_controller"):
		return {"ok": false, "error": "compose should expose turn_loop_controller via has_service"}
	if core.service("turn_loop_controller") == null:
		return {"ok": false, "error": "compose should wire turn_loop_controller"}
	core.dispose()
	return {"ok": true}

func _test_composer_build_manager_contract(harness) -> Dictionary:
	var manager_payload = harness.build_manager()
	if manager_payload.has("error"):
		return harness.fail_result(str(manager_payload["error"]))
	var manager = manager_payload["manager"]
	if not manager.container_factory.is_valid():
		return harness.fail_result("compose_manager should keep container_factory valid")
	if manager.command_builder == null or manager.command_id_factory == null or manager.public_snapshot_builder == null:
		return harness.fail_result("compose_manager should keep public ports wired")
	return harness.pass_result()
