extends SceneTree

const DeliveryRegistryLoaderScript := preload("res://src/composition/sample_battle_factory_delivery_registry_loader.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("EXPORT_FORMAL_DELIVERY_REGISTRY_FAILED: missing output path")
		quit(1)
		return
	var output_path := String(args[0]).strip_edges()
	if output_path.is_empty():
		printerr("EXPORT_FORMAL_DELIVERY_REGISTRY_FAILED: empty output path")
		quit(1)
		return
	var manifest_path := ""
	if args.size() >= 2:
		manifest_path = String(args[1]).strip_edges()
	var loader = DeliveryRegistryLoaderScript.new()
	if loader == null:
		printerr("EXPORT_FORMAL_DELIVERY_REGISTRY_FAILED: missing delivery registry loader")
		quit(1)
		return
	if not manifest_path.is_empty():
		loader.registry_path_override = manifest_path
	var entries_result: Dictionary = loader.load_entries_result()
	if not bool(entries_result.get("ok", false)):
		printerr(
			"EXPORT_FORMAL_DELIVERY_REGISTRY_FAILED: %s" % String(entries_result.get("error_message", "unknown error"))
		)
		quit(1)
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("EXPORT_FORMAL_DELIVERY_REGISTRY_FAILED: cannot open output path: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify({"entries": entries_result.get("data", [])}, "  "))
	file.flush()
	file.close()
	quit(0)
