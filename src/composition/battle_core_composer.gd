extends RefCounted
class_name BattleCoreComposer

const BattleCoreContainerScript := preload("res://src/composition/battle_core_container.gd")
const BattleCoreManagerScript := preload("res://src/battle_core/facades/battle_core_manager.gd")
const ServiceSpecsScript := preload("res://src/composition/battle_core_service_specs.gd")
const WiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs.gd")

class ContainerFactoryPort:
    extends RefCounted

    var composer

    func build_container():
        assert(composer != null, "ContainerFactoryPort requires composer")
        return composer.compose()

func compose():
    var container = BattleCoreContainerScript.new()
    _instantiate_services(container)
    _wire_dependencies(container)
    container.configure_dispose_specs(_resolve_service_slots(), WiringSpecsScript.WIRING_SPECS, WiringSpecsScript.RESET_SPECS)
    _assert_container_dependencies(container)
    return container

func compose_manager():
    var manager = BattleCoreManagerScript.new()
    assert(manager != null, "compose_manager requires manager")
    var factory_port = ContainerFactoryPort.new()
    factory_port.composer = self
    manager._container_factory_owner = factory_port
    manager.container_factory = Callable(factory_port, "build_container")
    manager.command_id_factory = _new_service_instance("id_factory")
    manager.command_builder = _new_service_instance("command_builder")
    manager.command_builder.id_factory = manager.command_id_factory
    manager.public_snapshot_builder = _new_service_instance("public_snapshot_builder")
    return manager

func _instantiate_services(container) -> void:
    for service_spec in ServiceSpecsScript.SERVICE_SPECS:
        var slot_name := str(service_spec["slot"])
        var script_ref = service_spec["script"]
        container.set(slot_name, script_ref.new())

func _wire_dependencies(container) -> void:
    for wiring_spec in WiringSpecsScript.WIRING_SPECS:
        var owner_name := str(wiring_spec["owner"])
        var dependency_name := str(wiring_spec["dependency"])
        var source_name := str(wiring_spec["source"])
        var owner = container.get(owner_name)
        assert(owner != null, "Composer missing owner: %s" % owner_name)
        owner.set(dependency_name, container.get(source_name))

func _assert_container_dependencies(container) -> void:
    for wiring_spec in WiringSpecsScript.WIRING_SPECS:
        _assert_dependency(container, str(wiring_spec["owner"]), str(wiring_spec["dependency"]))

func _resolve_service_slots() -> PackedStringArray:
    var service_slots := PackedStringArray()
    for service_spec in ServiceSpecsScript.SERVICE_SPECS:
        service_slots.append(str(service_spec["slot"]))
    return service_slots

func _new_service_instance(slot_name: String):
    var script_ref = ServiceSpecsScript.SCRIPT_BY_SLOT.get(slot_name, null)
    assert(script_ref != null, "Unknown service slot: %s" % slot_name)
    return script_ref.new()

func _assert_dependency(container, owner_name: String, dependency_name: String) -> void:
    var owner = container.get(owner_name)
    assert(owner != null, "Composer missing owner: %s" % owner_name)
    assert(owner.get(dependency_name) != null, "%s missing dependency: %s" % [owner_name, dependency_name])
