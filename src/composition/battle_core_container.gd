extends RefCounted
class_name BattleCoreContainer

var _services: Dictionary = {}

var _dispose_service_slots: PackedStringArray = PackedStringArray()
var _dispose_wiring_specs: Array = []
var _dispose_reset_specs: Array = []

func set_service(slot_name: String, service_instance) -> void:
	_services[slot_name] = service_instance

func service(slot_name: String) -> Variant:
	return _services.get(slot_name, null)

func has_service(slot_name: String) -> bool:
	return _services.has(slot_name) and _services[slot_name] != null

func clear_service(slot_name: String) -> void:
	_services.erase(slot_name)

func configure_dispose_specs(service_slots: PackedStringArray, wiring_specs: Array, reset_specs: Array = []) -> void:
	_dispose_service_slots = service_slots.duplicate()
	_dispose_wiring_specs = wiring_specs.duplicate(true)
	_dispose_reset_specs = reset_specs.duplicate(true)

func dispose() -> void:
	for wiring_spec in _dispose_wiring_specs:
		var owner_name := str(wiring_spec.get("owner", ""))
		var dependency_name := str(wiring_spec.get("dependency", ""))
		if owner_name.is_empty() or dependency_name.is_empty():
			continue
		var owner = service(owner_name)
		if owner != null:
			owner.set(dependency_name, null)
	for reset_spec in _dispose_reset_specs:
		var owner_name := str(reset_spec.get("owner", ""))
		var field_name := str(reset_spec.get("field", ""))
		if owner_name.is_empty() or field_name.is_empty():
			continue
		var owner = service(owner_name)
		if owner != null:
			owner.set(field_name, reset_spec.get("value", null))
	for slot_name in _dispose_service_slots:
		clear_service(String(slot_name))
	_dispose_service_slots = PackedStringArray()
	_dispose_wiring_specs.clear()
	_dispose_reset_specs.clear()
	_services.clear()
