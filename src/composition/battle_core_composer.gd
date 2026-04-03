extends RefCounted
class_name BattleCoreComposer

const BattleCoreContainerScript := preload("res://src/composition/battle_core_container.gd")
const BattleCoreManagerScript := preload("res://src/battle_core/facades/battle_core_manager.gd")
const ServiceSpecsScript := preload("res://src/composition/battle_core_service_specs.gd")
const WiringSpecsScript := preload("res://src/composition/battle_core_wiring_specs.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

class ContainerFactoryPort:
    extends RefCounted

    var composer

    func build_container():
        if composer == null:
            return null
        return composer.compose()

var last_error_code: Variant = null
var last_error_message: String = ""

func compose():
    last_error_code = null
    last_error_message = ""
    var container = BattleCoreContainerScript.new()
    if not _instantiate_services(container):
        return null
    if not _wire_dependencies(container):
        return null
    container.configure_dispose_specs(_resolve_service_slots(), WiringSpecsScript.WIRING_SPECS, WiringSpecsScript.RESET_SPECS)
    if not _validate_container_dependencies(container):
        container.dispose()
        return null
    return container

func compose_manager():
    last_error_code = null
    last_error_message = ""
    var manager = BattleCoreManagerScript.new()
    if manager == null:
        _fail("compose_manager requires manager")
        return null
    var factory_port = ContainerFactoryPort.new()
    factory_port.composer = self
    manager._container_factory_owner = factory_port
    manager.container_factory = Callable(factory_port, "build_container")
    manager.command_id_factory = _new_service_instance("id_factory")
    if manager.command_id_factory == null:
        return null
    manager.command_builder = _new_service_instance("command_builder")
    if manager.command_builder == null:
        return null
    manager.command_builder.id_factory = manager.command_id_factory
    manager.public_snapshot_builder = _new_service_instance("public_snapshot_builder")
    if manager.public_snapshot_builder == null:
        return null
    return manager

func _instantiate_services(container) -> bool:
    for slot_name in ServiceSpecsScript.service_slots():
        var script_ref = ServiceSpecsScript.script_by_slot(slot_name)
        if script_ref == null:
            return _fail("Unknown service slot: %s" % str(slot_name))
        container.set_service(slot_name, script_ref.new())
    return true

func _wire_dependencies(container) -> bool:
    for wiring_spec in WiringSpecsScript.WIRING_SPECS:
        var owner_name := str(wiring_spec["owner"])
        var dependency_name := str(wiring_spec["dependency"])
        var source_name := str(wiring_spec["source"])
        var owner = container.service(owner_name)
        if owner == null:
            return _fail("Composer missing owner: %s" % owner_name)
        owner.set(dependency_name, container.service(source_name))
    return true

func _validate_container_dependencies(container) -> bool:
    for wiring_spec in WiringSpecsScript.WIRING_SPECS:
        var owner_name := str(wiring_spec["owner"])
        var dependency_name := str(wiring_spec["dependency"])
        var owner = container.service(owner_name)
        if owner == null:
            return _fail("Composer missing owner: %s" % owner_name)
        if owner.get(dependency_name) == null:
            return _fail("%s missing dependency: %s" % [owner_name, dependency_name])
    for slot_name in ServiceSpecsScript.service_slots():
        var service = container.service(slot_name)
        if service == null:
            return _fail("Composer missing service: %s" % str(slot_name))
        if slot_name == "runtime_guard_service":
            continue
        if service.has_method("resolve_missing_dependency"):
            var missing_dependency := str(service.resolve_missing_dependency())
            if not missing_dependency.is_empty():
                return _fail("%s missing dependency: %s" % [slot_name, missing_dependency])
    return true

func _resolve_service_slots() -> PackedStringArray:
    return ServiceSpecsScript.service_slots()

func _new_service_instance(slot_name: String):
    var script_ref = ServiceSpecsScript.script_by_slot(slot_name)
    if script_ref == null:
        _fail("Unknown service slot: %s" % slot_name)
        return null
    return script_ref.new()

func _fail(message: String) -> bool:
    last_error_code = ErrorCodesScript.INVALID_COMPOSITION
    last_error_message = message
    return false
