extends "res://test/suites/content_validation_core/formal_registry/shared.gd"

const SetupSharedScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_setup_shared.gd")
const SetupMismatchSharedScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_setup_mismatch_shared.gd")
const SurfaceSharedScript := preload("res://test/suites/content_validation_core/formal_registry/catalog_factory_surface_shared.gd")

func _run_legacy_helper(script_ref, method_name: String, args: Array = []) -> void:
	var helper = script_ref.new()
	var result: Dictionary = helper.callv(method_name, args)
	helper.free()
	if typeof(result) != TYPE_DICTIONARY or not bool(result.get("ok", false)):
		fail(str(result.get("error", "unknown error")))
