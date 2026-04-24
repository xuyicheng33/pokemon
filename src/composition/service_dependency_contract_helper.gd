extends RefCounted
class_name ServiceDependencyContractHelper

const ServiceSpecsScript := preload("res://src/composition/battle_core_service_specs.gd")
const PropertyAccessHelperScript := preload("res://src/shared/property_access_helper.gd")

const COMPOSE_DEPS_CONST := "COMPOSE_DEPS"
const COMPOSE_RESET_FIELDS_CONST := "COMPOSE_RESET_FIELDS"

static func resolve_missing_dependency(service, skip_fields: PackedStringArray = PackedStringArray()) -> String:
	var skip_lookup: Dictionary = {}
	for raw_field in skip_fields:
		var field_name := String(raw_field).strip_edges()
		if field_name.is_empty():
			continue
		skip_lookup[field_name] = true
	return _resolve_missing_dependency_recursive(service, skip_lookup, {})

static func dependency_edges(service_slots: PackedStringArray = PackedStringArray()) -> Array:
	var edges: Array = []
	for raw_slot_name in _normalized_service_slots(service_slots):
		var slot_name := String(raw_slot_name)
		var script_ref = ServiceSpecsScript.script_by_slot(slot_name)
		for dependency_spec in compose_deps(script_ref):
			var source_name := String(dependency_spec.get("source", "")).strip_edges()
			if source_name.is_empty():
				continue
			edges.append({
				"owner": slot_name,
				"dependency": String(dependency_spec.get("field", "")),
				"source": source_name,
			})
	return edges

static func compose_reset_specs(service_slots: PackedStringArray = PackedStringArray()) -> Array:
	var reset_specs: Array = []
	for raw_slot_name in _normalized_service_slots(service_slots):
		var slot_name := String(raw_slot_name)
		var script_ref = ServiceSpecsScript.script_by_slot(slot_name)
		for reset_spec in compose_reset_fields(script_ref):
			reset_specs.append({
				"owner": slot_name,
				"field": String(reset_spec.get("field", "")),
				"value": reset_spec.get("value", null),
			})
	return reset_specs

static func compose_deps(target) -> Array:
	var normalized_specs: Array = []
	for raw_spec in _constant_array(target, COMPOSE_DEPS_CONST):
		if not (raw_spec is Dictionary):
			continue
		var dependency_spec := Dictionary(raw_spec)
		var field_name := String(dependency_spec.get("field", "")).strip_edges()
		if field_name.is_empty():
			continue
		normalized_specs.append({
			"field": field_name,
			"source": String(dependency_spec.get("source", field_name)).strip_edges(),
			"nested": not dependency_spec.has("nested") or bool(dependency_spec.get("nested", true)),
		})
	return normalized_specs

static func compose_reset_fields(target) -> Array:
	var normalized_specs: Array = []
	for raw_spec in _constant_array(target, COMPOSE_RESET_FIELDS_CONST):
		if not (raw_spec is Dictionary):
			continue
		var reset_spec := Dictionary(raw_spec)
		var field_name := String(reset_spec.get("field", "")).strip_edges()
		if field_name.is_empty():
			continue
		normalized_specs.append({
			"field": field_name,
			"value": reset_spec.get("value", null),
		})
	return normalized_specs

static func _normalized_service_slots(service_slots: PackedStringArray) -> PackedStringArray:
	if not service_slots.is_empty():
		return service_slots
	return ServiceSpecsScript.service_slots()

static func _resolve_missing_dependency_recursive(service, skip_lookup: Dictionary, visited: Dictionary) -> String:
	if service == null:
		return "missing"
	var visit_key := _visit_key(service)
	if not visit_key.is_empty():
		if visited.has(visit_key):
			return ""
		visited[visit_key] = true
	for dependency_spec in compose_deps(service):
		var field_name := String(dependency_spec.get("field", "")).strip_edges()
		if field_name.is_empty() or skip_lookup.has(field_name):
			continue
		var dependency = _read_property(service, field_name, null)
		if dependency == null:
			return field_name
		if not bool(dependency_spec.get("nested", true)):
			continue
		var nested_missing := _resolve_nested_missing_dependency(dependency, skip_lookup, visited)
		if not nested_missing.is_empty():
			return "%s.%s" % [field_name, nested_missing]
	return ""

static func _resolve_nested_missing_dependency(dependency, skip_lookup: Dictionary, visited: Dictionary) -> String:
	if dependency == null:
		return "missing"
	if not compose_deps(dependency).is_empty():
		return _resolve_missing_dependency_recursive(dependency, skip_lookup, visited)
	return _call_zero_arg_missing_dependency(dependency)

static func _call_zero_arg_missing_dependency(dependency) -> String:
	if dependency == null or typeof(dependency) != TYPE_OBJECT or not dependency.has_method("resolve_missing_dependency"):
		return ""
	for method_info in dependency.get_method_list():
		if String(method_info.get("name", "")) != "resolve_missing_dependency":
			continue
		var args = method_info.get("args", [])
		if args is Array and args.size() == 0:
			return str(dependency.call("resolve_missing_dependency"))
	return ""

static func _constant_array(target, constant_name: String) -> Array:
	if constant_name.is_empty():
		return []
	var script_ref = _script_for_target(target)
	if script_ref == null or not script_ref.has_method("get_script_constant_map"):
		return []
	var constant_map: Dictionary = script_ref.get_script_constant_map()
	var value = constant_map.get(constant_name, [])
	return Array(value)

static func _script_for_target(target) -> Variant:
	if target == null:
		return null
	if target is Script:
		return target
	if typeof(target) == TYPE_STRING:
		return ServiceSpecsScript.script_by_slot(String(target))
	if typeof(target) != TYPE_OBJECT:
		return null
	return target.get_script()

static func _read_property(value, property_name: String, default_value = null) -> Variant:
	return PropertyAccessHelperScript.read_property(value, property_name, default_value)

static func _visit_key(value) -> String:
	if value == null:
		return ""
	if value is Script:
		return "script:%s" % String(value.resource_path)
	if typeof(value) != TYPE_OBJECT:
		return ""
	return "%s#%d" % [String(value.get_script().resource_path), int(value.get_instance_id())]
