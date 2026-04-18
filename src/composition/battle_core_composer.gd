extends RefCounted
class_name BattleCoreComposer

const BattleCoreContainerScript := preload("res://src/composition/battle_core_container.gd")
const BattleCoreManagerScript := preload("res://src/battle_core/facades/battle_core_manager.gd")
const BattleCoreManagerContainerServiceScript := preload("res://src/battle_core/facades/battle_core_manager_container_service.gd")
const EventLogPublicSnapshotBuilderScript := preload("res://src/battle_core/facades/event_log_public_snapshot_builder.gd")
const ServiceSpecsScript := preload("res://src/composition/battle_core_service_specs.gd")
const ServiceDependencyContractHelperScript := preload("res://src/composition/service_dependency_contract_helper.gd")
const ErrorCodesScript := preload("res://src/shared/error_codes.gd")

class ContainerFactoryPort:
    extends RefCounted

    var composer

    func build_container() -> Variant:
        if composer == null:
            return null
        return composer.compose()

    func error_state() -> Dictionary:
        if composer == null:
            return {
                "code": ErrorCodesScript.INVALID_COMPOSITION,
                "message": "BattleCoreComposer factory port missing composer",
            }
        return composer.error_state()

var last_error_code: Variant = null
var last_error_message: String = ""
var _shared_content_snapshot_cache = null

func error_state() -> Dictionary:
    return {
        "code": last_error_code,
        "message": last_error_message,
    }

func shared_content_snapshot_cache() -> Variant:
    if _shared_content_snapshot_cache == null:
        _shared_content_snapshot_cache = _new_service_instance("content_snapshot_cache")
    return _shared_content_snapshot_cache

func compose() -> Variant:
    last_error_code = null
    last_error_message = ""
    var service_slots := _resolve_service_slots()
    var wiring_specs := ServiceDependencyContractHelperScript.dependency_edges(service_slots)
    var reset_specs := ServiceDependencyContractHelperScript.compose_reset_specs(service_slots)
    var container = BattleCoreContainerScript.new()
    if not _instantiate_services(container):
        return null
    if not _wire_dependencies(container, wiring_specs):
        return null
    container.configure_dispose_specs(service_slots, wiring_specs, reset_specs)
    if not _validate_container_dependencies(container, service_slots, wiring_specs):
        container.dispose()
        return null
    return container

func compose_manager() -> Variant:
    last_error_code = null
    last_error_message = ""
    var factory_port = ContainerFactoryPort.new()
    factory_port.composer = self
    return compose_manager_with_factory(Callable(factory_port, "build_container"), factory_port)

func compose_manager_with_factory(container_factory: Callable, container_factory_owner = null) -> Variant:
    last_error_code = null
    last_error_message = ""
    var manager = BattleCoreManagerScript.new()
    if manager == null:
        _fail("compose_manager requires manager")
        return null
    var command_id_factory = _new_service_instance("id_factory")
    if command_id_factory == null:
        return null
    var command_builder = _new_service_instance("command_builder")
    if command_builder == null:
        return null
    var public_snapshot_builder = _new_service_instance("public_snapshot_builder")
    if public_snapshot_builder == null:
        return null
    var event_log_public_snapshot_builder = EventLogPublicSnapshotBuilderScript.new()
    if event_log_public_snapshot_builder == null:
        _fail("compose_manager requires event_log_public_snapshot_builder")
        return null
    var container_service = BattleCoreManagerContainerServiceScript.new()
    if container_service == null:
        _fail("compose_manager requires container_service")
        return null
    manager._configure_core_ports(
        container_factory,
        command_builder,
        command_id_factory,
        public_snapshot_builder,
        event_log_public_snapshot_builder,
        container_service,
        container_factory_owner
    )
    return manager

func _instantiate_services(container) -> bool:
    for slot_name in ServiceSpecsScript.service_slots():
        var script_ref = ServiceSpecsScript.script_by_slot(slot_name)
        if script_ref == null:
            return _fail("Unknown service slot: %s" % str(slot_name))
        if slot_name == "content_snapshot_cache":
            var shared_cache = shared_content_snapshot_cache()
            if shared_cache == null:
                return _fail("Failed to build shared content_snapshot_cache")
            container.set_service(slot_name, shared_cache)
            continue
        container.set_service(slot_name, script_ref.new())
    return true

func _wire_dependencies(container, wiring_specs: Array) -> bool:
    for wiring_spec in wiring_specs:
        var owner_name := str(wiring_spec["owner"])
        var dependency_name := str(wiring_spec["dependency"])
        var source_name := str(wiring_spec["source"])
        var owner = container.service(owner_name)
        if owner == null:
            return _fail("Composer missing owner: %s" % owner_name)
        var dependency = container.service(source_name)
        if dependency == null:
            return _fail("Composer missing source service: %s" % source_name)
        if not _owner_declares_dependency(owner, dependency_name):
            return _fail("%s missing declared dependency slot: %s" % [owner_name, dependency_name])
        owner.set(dependency_name, dependency)
    return true

func _validate_container_dependencies(container, service_slots: PackedStringArray, wiring_specs: Array) -> bool:
    for wiring_spec in wiring_specs:
        var owner_name := str(wiring_spec["owner"])
        var dependency_name := str(wiring_spec["dependency"])
        var owner = container.service(owner_name)
        if owner == null:
            return _fail("Composer missing owner: %s" % owner_name)
        if not _owner_declares_dependency(owner, dependency_name):
            return _fail("%s missing declared dependency slot: %s" % [owner_name, dependency_name])
        if owner.get(dependency_name) == null:
            return _fail("%s missing dependency: %s" % [owner_name, dependency_name])
    for slot_name in service_slots:
        var service = container.service(slot_name)
        if service == null:
            return _fail("Composer missing service: %s" % str(slot_name))
        var missing_dependency := ServiceDependencyContractHelperScript.resolve_missing_dependency(service)
        if not missing_dependency.is_empty():
            return _fail("%s missing dependency: %s" % [slot_name, missing_dependency])
    return true

func _resolve_service_slots() -> PackedStringArray:
    return ServiceSpecsScript.service_slots()

func _new_service_instance(slot_name: String) -> Variant:
    var script_ref = ServiceSpecsScript.script_by_slot(slot_name)
    if script_ref == null:
        _fail("Unknown service slot: %s" % slot_name)
        return null
    return script_ref.new()

func _owner_declares_dependency(owner, dependency_name: String) -> bool:
    if owner == null or dependency_name.is_empty():
        return false
    for property_info in owner.get_property_list():
        if String(property_info.get("name", "")) == dependency_name:
            return true
    return false

func _fail(message: String) -> bool:
    last_error_code = ErrorCodesScript.INVALID_COMPOSITION
    last_error_message = message
    return false
